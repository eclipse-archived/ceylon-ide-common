import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    ModelUtil {
        isTypeUnknown,
        intersectionType,
        unionType
    },
    Declaration,
    Reference,
    TypedDeclaration,
    TypeDeclaration,
    Interface
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}

class InferredType(Unit unit) {
    
    shared variable Type? inferredType = null;
    shared variable Type? generalizedType = null;
    
    shared void intersect(Type pt) {
        if (!isTypeUnknown(pt)) {
            if (!exists g = generalizedType) {
                generalizedType = pt;
            } else {
                value it = intersectionType(generalizedType, pt, unit);
                if (!it.nothing) {
                    generalizedType = it;
                }
            }
        }
    }
    
    shared void union(Type pt) {
        if (!isTypeUnknown(pt)) {
            if (!exists i = inferredType) {
                inferredType = pt;
            } else {
                inferredType = unionType(inferredType, unit.denotableType(pt), unit);
            }
        }
    }
}

class InferTypeVisitor(Unit unit) extends Visitor() {
    shared InferredType result = InferredType(unit);
    shared variable Declaration? declaration = null;
    variable Reference? pr = null;
    
    shared actual void visit(Tree.AttributeDeclaration that) {
        super.visit(that);
        //TODO: an assignment to something with an inferred
        //      type doesn't _directly_ constrain the type
        //      ... but _indirectly_ it can!
        value term = that.specifierOrInitializerExpression?.expression?.term;

        if (is Tree.BaseMemberExpression term) {
            value bme = term;
            if (exists d = bme.declaration, exists dec = declaration, d.equals(dec)) {
                value t = that.type.typeModel;
                result.intersect(t);
            }
        } else if (exists term, exists dec = declaration) {
            if (that.declarationModel.equals(dec)) {
                result.union(term.typeModel);
            }
        }
    }

    shared actual void visit(Tree.MethodDeclaration that) {
        super.visit(that);
        //TODO: an assignment to something with an inferred
        //      type doesn't _directly_ constrain the type
        //      ... but _indirectly_ it can!
        value term = that.specifierExpression?.expression?.term;

        if (is Tree.BaseMemberExpression term) {
            value bme = term;

            if (exists d = bme.declaration, exists dec = declaration, d.equals(dec)) {
                value t = that.type.typeModel;
                result.intersect(t);
            }
        } else if (exists term, exists dec = declaration) {
            if (that.declarationModel.equals(dec)) {
                result.union(term.typeModel);
            }
        }
    }

    shared actual void visit(Tree.SpecifierStatement that) {
        super.visit(that);
        Tree.Term? bme = that.baseMemberExpression;
        value term = that.specifierExpression?.expression?.term;
        
        if (is Tree.BaseMemberExpression bme) {
            value ibme = bme;
            if (exists d = ibme.declaration, exists dec = declaration, d.equals(dec)) {
                if (exists term) {
                    result.union(term.typeModel);
                }
            }
        }
        
        if (is Tree.BaseMemberExpression term) {
            value ibme = term;
            if (exists d = ibme.declaration, exists dec = declaration, d.equals(dec)) {
                if (exists bme) {
                    result.intersect(bme.typeModel);
                }
            }
        }
    }

    shared actual void visit(Tree.AssignmentOp that) {
        super.visit(that);
        Tree.Term? rt = that.rightTerm;
        Tree.Term? lt = that.leftTerm;
        
        if (is Tree.BaseMemberExpression lt) {
            if (exists dec = declaration, lt.declaration.equals(dec)) {
                if (exists rt) {
                    result.union(rt.typeModel);
                }
            }
        }
        
        if (is Tree.BaseMemberExpression rt) {
            if (exists dec = declaration, rt.declaration.equals(dec)) {
                if (exists lt) {
                    result.intersect(lt.typeModel);
                }
            }
        }
    }

    shared actual void visit(Tree.InvocationExpression that) {
        value opr = null;

        if (exists primary = that.primary) {
            if (is Tree.MemberOrTypeExpression primary) {
                value mte = primary;
                pr = mte.target;
            }
        }
        
        super.visit(that);
        pr = opr;
    }
    
    shared actual void visit(Tree.ListedArgument that) {
        super.visit(that);
        value t = that.expression.term;
        
        if (is Tree.BaseMemberExpression t) {
            value bme = t;

            if (exists d = bme.declaration, exists dec = declaration, d.equals(dec)) {
                if (exists p = that.parameter, exists _pr = pr) {
                    variable value ft = _pr.getTypedParameter(p).fullType;
                    if (p.sequenced) {
                        ft = unit.getIteratedType(ft);
                    }
                    
                    result.intersect(ft);
                }
            }
        }
    }

    shared actual void visit(Tree.SpreadArgument that) {
        super.visit(that);
        value t = that.expression.term;
        if (is Tree.BaseMemberExpression t) {
            value bme = t;
            if (exists d = bme.declaration, exists dec = declaration, d.equals(dec)) {
                if (exists p = that.parameter, exists _pr = pr) {
                    value ft = _pr.getTypedParameter(p).fullType;
                    value et = unit.getIteratedType(ft);
                    value it = unit.getIterableType(et);
                    result.intersect(it);
                }
            }
        }
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        super.visit(that);
        value t = that.specifierExpression.expression.term;
        if (is Tree.BaseMemberExpression t) {
            value bme = t;
            if (exists d = bme.declaration, exists dec = declaration, d.equals(dec)) {
                if (exists p = that.parameter, exists _pr = pr) {
                    value ft = _pr.getTypedParameter(p).fullType;
                    result.intersect(ft);
                }
            }
        }
    }

    shared actual void visit(Tree.Return that) {
        super.visit(that);
        Tree.Term? bme = that.expression?.term;
        if (is Tree.BaseMemberExpression bme) {
            value ibme = bme;
            if (exists bmed = ibme.declaration, exists dec= declaration,
                bmed.equals(dec)) {
                
                value d = that.declaration;
                if (is TypedDeclaration d) {
                    value td = d;
                    result.intersect(td.type);
                }
            }
        } else if (exists bme, exists dec = declaration) {
            if (that.declaration.equals(dec)) {
                result.union(bme.typeModel);
            }
        }
    }

    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        super.visit(that);
        value primary = that.primary;
        if (is Tree.BaseMemberExpression primary) {
            value bme = primary;
            if (exists bmed = bme.declaration, exists dec = declaration,
                bmed.equals(dec)) {
                
                assert (is TypeDeclaration td = that.declaration.refinedDeclaration.container);
                value st = that.target.qualifyingType.getSupertype(td);
                result.intersect(st);
            }
        }
    }

    shared actual void visit(Tree.ValueIterator that) {
        super.visit(that);
        value primary = that.specifierExpression.expression.term;
        if (is Tree.BaseMemberExpression primary) {
            value bme = primary;
            if (exists bmed = bme.declaration, exists dec = declaration,
                bmed.equals(dec)) {
                
                value vt = that.variable.type.typeModel;
                value it = unit.getIterableType(vt);
                result.intersect(it);
            }
        }
    }

    shared actual void visit(Tree.BooleanCondition that) {
        super.visit(that);
        value primary = that.expression.term;
        if (is Tree.BaseMemberExpression primary) {
            value bme = primary;
            if (exists bmed = bme.declaration, exists dec = declaration,
                bmed.equals(dec)) {
                
                value bt = unit.booleanDeclaration.type;
                result.intersect(bt);
            }
        }
    }

    shared actual void visit(Tree.NonemptyCondition that) {
        super.visit(that);
        value s = that.variable;
        if (is Tree.Variable s) {
            value var = s;
            value primary = var.specifierExpression.expression.term;
            if (is Tree.BaseMemberExpression primary) {
                value bme = primary;
                if (exists bmed = bme.declaration, exists dec = declaration,
                    bmed.equals(dec)) {
                    
                    value vt = var.type.typeModel;
                    value et = unit.getSequentialElementType(vt);
                    value st = unit.getSequentialType(et);
                    result.intersect(st);
                }
            }
        }
    }

    shared actual void visit(Tree.ArithmeticOp that) {
        super.visit(that);
        value sd = getArithmeticDeclaration(that);
        genericOperatorTerm(sd, that.leftTerm);
        genericOperatorTerm(sd, that.rightTerm);
    }

    shared actual void visit(Tree.NegativeOp that) {
        super.visit(that);
        value sd = unit.invertableDeclaration;
        genericOperatorTerm(sd, that.term);
    }
    
    shared actual void visit(Tree.PrefixOperatorExpression that) {
        super.visit(that);
        value sd = unit.ordinalDeclaration;
        genericOperatorTerm(sd, that.term);
    }
    
    shared actual void visit(Tree.PostfixOperatorExpression that) {
        super.visit(that);
        value sd = unit.ordinalDeclaration;
        genericOperatorTerm(sd, that.term);
    }
    
    shared actual void visit(Tree.BitwiseOp that) {
        super.visit(that);
        value sd = unit.setDeclaration;
        genericOperatorTerm(sd, that.leftTerm);
        genericOperatorTerm(sd, that.rightTerm);
    }
    
    shared actual void visit(Tree.ComparisonOp that) {
        super.visit(that);
        value sd = unit.comparableDeclaration;
        genericOperatorTerm(sd, that.leftTerm);
        genericOperatorTerm(sd, that.rightTerm);
    }
    
    shared actual void visit(Tree.CompareOp that) {
        super.visit(that);
        value sd = unit.comparableDeclaration;
        genericOperatorTerm(sd, that.leftTerm);
        genericOperatorTerm(sd, that.rightTerm);
    }
    
    shared actual void visit(Tree.LogicalOp that) {
        super.visit(that);
        value sd = unit.booleanDeclaration;
        operatorTerm(sd, that.leftTerm);
        operatorTerm(sd, that.rightTerm);
    }
    
    shared actual void visit(Tree.NotOp that) {
        super.visit(that);
        value sd = unit.booleanDeclaration;
        operatorTerm(sd, that.term);
    }
    
    shared actual void visit(Tree.EntryOp that) {
        super.visit(that);
        value sd = unit.objectDeclaration;
        operatorTerm(sd, that.leftTerm);
        operatorTerm(sd, that.rightTerm);
    }

    Interface getArithmeticDeclaration(Tree.ArithmeticOp that) {
        if (is Tree.PowerOp that) {
            return unit.exponentiableDeclaration;
        } else if (is Tree.SumOp that) {
            return unit.summableDeclaration;
        } else if (is Tree.DifferenceOp that) {
            return unit.invertableDeclaration;
        } else if (is Tree.RemainderOp that) {
            return unit.integralDeclaration;
        } else {
            return unit.numericDeclaration;
        }
    }
    
    shared void operatorTerm(TypeDeclaration sd, Tree.Term lhs) {
        if (is Tree.BaseMemberExpression lhs) {
            value bme = lhs;
            if (exists bmed = bme.declaration, exists dec = declaration,
                bmed.equals(dec)) {
                
                result.intersect(sd.type);
            }
        }
    }
    
    shared void genericOperatorTerm(TypeDeclaration sd, Tree.Term lhs) {
        if (is Tree.BaseMemberExpression lhs) {
            value bme = lhs;
            if (exists bmed = bme.declaration, exists dec = declaration,
                bmed.equals(dec)) {
                
                value st = lhs.typeModel.getSupertype(sd);
                value at = st.typeArguments.get(0);
                result.intersect(at);
            }
        }
    }

    //TODO: more operator expressions!
}
