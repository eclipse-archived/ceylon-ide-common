import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}
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

class InferredType(Unit unit) {
    
    shared variable Type? inferredType = null;
    shared variable Type? generalizedType = null;
    
    shared void intersect(Type pt) {
        if (!isTypeUnknown(pt)) {
            if (!generalizedType exists) {
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
            if (!inferredType exists) {
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
            if (exists d = bme.declaration, 
                exists dec = declaration, 
                d == dec, 
                exists t = that.type.typeModel) {
                result.intersect(t);
            }
        } else if (exists term, 
                   exists dec = declaration, 
                   that.declarationModel == dec,
                   exists t = term.typeModel) {
            result.union(t);
        }
    }

    shared actual void visit(Tree.MethodDeclaration that) {
        super.visit(that);
        //TODO: an assignment to something with an inferred
        //      type doesn't _directly_ constrain the type
        //      ... but _indirectly_ it can!
        value term = that.specifierExpression?.expression?.term;

        if (is Tree.BaseMemberExpression term) {
            if (exists d = term.declaration, 
                exists dec = declaration, 
                d == dec, 
                exists t = that.type.typeModel) {
                result.intersect(t);
            }
        } else if (exists term, 
                   exists dec = declaration, 
                   that.declarationModel == dec,
                   exists t = term.typeModel) {
            result.union(t);
        }
    }

    shared actual void visit(Tree.SpecifierStatement that) {
        super.visit(that);
        Tree.Term? bme = that.baseMemberExpression;
        value term = that.specifierExpression?.expression?.term;
        
        if (is Tree.BaseMemberExpression bme) {
            value ibme = bme;
            if (exists d = ibme.declaration, 
                exists dec = declaration, 
                d == dec, 
                exists term,
                exists t = term.typeModel) {
                result.union(t);
            }
        }
        
        if (is Tree.BaseMemberExpression term) {
            value ibme = term;
            if (exists d = ibme.declaration, 
                exists dec = declaration, 
                d == dec, 
                exists bme,
                exists t = bme.typeModel) {
                result.intersect(t);
            }
        }
    }

    shared actual void visit(Tree.AssignmentOp that) {
        super.visit(that);
        Tree.Term? rt = that.rightTerm;
        Tree.Term? lt = that.leftTerm;
        
        if (is Tree.BaseMemberExpression lt, 
            exists dec = declaration, 
            lt.declaration == dec, 
            exists rt, exists rtt = rt.typeModel) {
            result.union(rtt);
        }
        
        if (is Tree.BaseMemberExpression rt, 
            exists dec = declaration, 
            rt.declaration == dec, 
            exists lt, exists ltt = lt.typeModel) {
            result.intersect(ltt);
        }
    }

    shared actual void visit(Tree.InvocationExpression that) {
        //value opr = null;

        if (exists primary = that.primary) {
            if (is Tree.MemberOrTypeExpression primary) {
                value mte = primary;
                pr = mte.target;
            }
        }
        
        super.visit(that);
        //pr = opr;
        pr = null;
    }
    
    shared actual void visit(Tree.ListedArgument that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression t 
                = that.expression?.term, 
            exists d = t.declaration, 
            exists dec = declaration, 
            d == dec, 
            exists p = that.parameter, 
            exists pr = this.pr) {
            value ft = pr.getTypedParameter(p).fullType;
            if (p.sequenced) {
                result.intersect(unit.getIteratedType(ft));
            }
            else {
                result.intersect(ft);
            }
        }
    }

    shared actual void visit(Tree.SpreadArgument that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression t 
                = that.expression?.term, 
            exists d = t.declaration, 
            exists dec = declaration, 
            d == dec, 
            exists p = that.parameter, 
            exists pr = this.pr) {
            
            value ft = pr.getTypedParameter(p).fullType;
            value et = unit.getIteratedType(ft);
            value it = unit.getIterableType(et);
            result.intersect(it);
        }
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression t 
                = that.specifierExpression?.expression?.term, 
            exists d = t.declaration, 
            exists dec = declaration, 
            d == dec, 
            exists p = that.parameter, 
            exists _pr = pr) {
            
            value ft = _pr.getTypedParameter(p).fullType;
            result.intersect(ft);
        }
    }

    shared actual void visit(Tree.Return that) {
        super.visit(that);
        Tree.Term? bme = that.expression?.term;
        if (is Tree.BaseMemberExpression bme) {
            if (exists bmed = bme.declaration, 
                exists dec= declaration,
                bmed == dec, 
                is TypedDeclaration d = that.declaration,
                exists t = d.type) {
                result.intersect(t);
            }
        }
        else if (exists bme, 
                 exists dec = declaration, 
                 that.declaration == dec,
                 exists t = bme.typeModel) {
            result.union(t);
        }
    }

    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression primary = that.primary, 
            exists bmed = primary.declaration, 
            exists dec = declaration,
            bmed == dec,
            is TypeDeclaration td 
                    = that.declaration?.refinedDeclaration?.container,
            exists st = that.target?.qualifyingType?.getSupertype(td)) {
            result.intersect(st);
        }
    }

    shared actual void visit(Tree.ValueIterator that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression primary =
                that.specifierExpression?.expression?.term,
            exists bmed = primary.declaration, 
            exists dec = declaration,
            bmed == dec, 
            exists vt = that.variable.type.typeModel) {
            
            value it = unit.getIterableType(vt);
            result.intersect(it);
        }
    }

    shared actual void visit(Tree.BooleanCondition that) {
        super.visit(that);
        if (is Tree.BaseMemberExpression primary =
                that.expression?.term,
            exists bmed = primary.declaration, 
            exists dec = declaration,
            bmed == dec) {
            
            value bt = unit.booleanType;
            result.intersect(bt);
        }
    }

    shared actual void visit(Tree.NonemptyCondition that) {
        super.visit(that);
        if (is Tree.Variable var = that.variable, 
            is Tree.BaseMemberExpression primary 
                    = var.specifierExpression?.expression?.term, 
            exists bmed = primary.declaration, 
            exists dec = declaration,
            bmed == dec, 
            exists vt = var.type.typeModel) {
            
            value et = unit.getSequentialElementType(vt);
            value st = unit.getSequentialType(et);
            result.intersect(st);
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
        switch (that)
        case (is Tree.PowerOp) {
            return unit.exponentiableDeclaration;
        } case (is Tree.SumOp) {
            return unit.summableDeclaration;
        } case (is Tree.DifferenceOp) {
            return unit.invertableDeclaration;
        } case (is Tree.RemainderOp) {
            return unit.integralDeclaration;
        } else {
            return unit.numericDeclaration;
        }
    }
    
    shared void operatorTerm(TypeDeclaration sd, Tree.Term? lhs) {
        if (is Tree.BaseMemberExpression lhs, 
            exists bmed = lhs.declaration, 
            exists dec = declaration,
            bmed == dec) {
            
            result.intersect(sd.type);
        }
    }
    
    shared void genericOperatorTerm(TypeDeclaration sd, Tree.Term? lhs) {
        if (is Tree.BaseMemberExpression lhs, 
            exists bmed = lhs.declaration, 
            exists dec = declaration,
            bmed == dec, 
            exists lhst = lhs.typeModel,
            exists st = lhst.getSupertype(sd),
            exists at = st.typeArgumentList[0]) {
            
            result.intersect(at);
        }
    }

    //TODO: more operator expressions!
}
