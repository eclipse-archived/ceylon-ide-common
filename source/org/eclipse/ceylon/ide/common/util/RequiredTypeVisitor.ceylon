import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Functional,
    Parameter,
    Reference,
    Type,
    Unit,
    ModelUtil,
    Declaration
}

import java.lang {
    overloaded
}

import org.antlr.runtime {
    CommonToken,
    Token
}

shared class RequiredTypeVisitor(Node node, Token? token)
        extends Visitor()
        satisfies RequiredType {
    
    variable Type? requiredType = null;
    variable Type? finalResult = null;
    variable Parameter? parameterResult = null;
    variable Parameter? finalParameter = null;
    variable Reference? namedArgTarget = null;
    variable String? paramName = null;
    
    type => finalResult;
    parameterName => paramName;
    parameter => finalParameter;
    
    shared actual void visitAny(Node that) {
        if (node == that) {
            finalResult = requiredType;

            switch (that)
            case (is Tree.PositionalArgument) {
                if (exists parameter = that.parameter) {
                    paramName = parameter.name;
                }
            }
            case (is Tree.NamedArgument) {
                if (exists parameter = that.parameter) {
                    paramName = parameter.name;
                }
            }
            else {}
        }
        super.visitAny(that);
    }

    overloaded
    shared actual void visit(Tree.Body that) {
        value ort = requiredType;
        requiredType = null;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.Declaration that) {
        value ort = requiredType;
        requiredType = null;
        super.visit(that);
        requiredType = ort;
    }

    function getTarget(Tree.InvocationExpression that)
            => if (is Tree.MemberOrTypeExpression primary = that.primary)
            then primary.target
            else null;

    function getParameters(Reference reference)
            => if (is Functional declaration = reference.declaration)
            then declaration.parameterLists[0]?.parameters
            else null;

    overloaded
    shared actual void visit(Tree.InvocationExpression that) {
        if (exists p = that.primary) {
            p.visit(this);
        }
        value ort = requiredType;
        value onat = namedArgTarget;

        Unit? unit = that.unit;
        if (!exists unit) {
            return;
        }

        if (exists pal = that.positionalArgumentList) {
            variable Integer pos;
            value pas = pal.positionalArguments;
            if (pas.empty) {
                pos = 0;
            } else {
                pos = pas.size(); //default to the last argument if incomplete
                for (i in 0:pas.size()) {
                    value pa = pas[i];
                    if (exists token) {
                        assert (is CommonToken token);
                        value tokenEnd = token.stopIndex + 1;
                        if (exists end = pa?.endIndex,
                            end.intValue() >= tokenEnd) {
                            pos = i;
                            break;
                        }
                    }
                    else {
                        if (exists start = pa?.startIndex,
                            exists end = pa?.endIndex,
                            node.startIndex.intValue()
                                >= start.intValue(),
                            node.endIndex.intValue() 
                                <= end.intValue()) {
                            pos = i;
                            break;
                        }
                    }
                }
            }
            
            if (exists pr = getTarget(that)) {
                if (exists params = getParameters(pr)) {
                    if (params.size() > pos) {
                        Parameter param = params.get(pos);
                        this.parameterResult = param;
                        if (exists qualifiedNameString = pr.declaration?.qualifiedNameString,
                            qualifiedNameString =="ceylon.language::print") {
                            requiredType = unit.stringDeclaration?.type;
                        } else {
                            requiredType = pr.getTypedParameter(param).fullType;
                            if (param.sequenced) {
                                requiredType = unit.getIteratedType(requiredType);
                            }
                        }
                    } else if (!params.empty) {
                        Parameter param = params.get(params.size() - 1);
                        this.parameterResult = param;
                        if (param.sequenced) {
                            requiredType = pr.getTypedParameter(param).fullType;
                            requiredType = unit.getIteratedType(requiredType);
                        }
                    }
                }
            } else {
                //indirect invocations
                if (exists ct = that.primary?.typeModel,
                    unit.isCallableType(ct)) {
                    value pts = unit.getCallableArgumentTypes(ct);
                    
                    if (pts.size() > pos) {
                        requiredType = pts.get(pos);
                    }
                }
            }
        }

        if (exists nal = that.namedArgumentList) {
            namedArgTarget = getTarget(that);
            if (exists nat = namedArgTarget,
                exists params = getParameters(nat),
                !params.empty) {
                
                value param = params[params.size()-1];
                this.parameterResult = param;
                if (exists param, unit.isIterableType(param.type)) {
                    requiredType = nat.getTypedParameter(param).fullType;
                    requiredType = unit.getIteratedType(requiredType);
                }
            }
        }
        if (node===that.positionalArgumentList
         || node===that.namedArgumentList) {
            finalResult = requiredType;
            finalParameter = this.parameterResult;
        }

        that.namedArgumentList?.visit(this);
        that.positionalArgumentList?.visit(this);

        requiredType = ort;
        namedArgTarget = onat;
    }

    overloaded
    shared actual void visit(Tree.SpecifiedArgument that) {
        value ort = requiredType;
        if (exists parameter = that.parameter) {
            requiredType
                    = if (exists nat = namedArgTarget)
                    then nat.getTypedParameter(parameter).type
                    else parameter.type;
        }
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.ForIterator that) {
        value ort = requiredType;
        if (exists unit = that.unit) {
            requiredType = unit.getIterableType(unit.anythingType);
        }
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.SpecifierStatement that) {
        value ort = requiredType;
        requiredType = that.baseMemberExpression?.typeModel;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.SwitchStatement that) {
        value ort = requiredType;
        Type? srt;
        if (exists switchClause = that.switchClause) {
            switchClause.visit(this);
            if (exists e = switchClause.switched?.expression) {
                srt = e.typeModel;
            } else if (exists v = switchClause.switched?.variable) {
                srt = v.type?.typeModel;
            } else {
                srt = null;
            }
        }
        else {
            srt = null;
        }
        
        if (exists switchCaseList = that.switchCaseList,
            exists caseClauses = switchCaseList.caseClauses) {
            for (cc in caseClauses) {
                if (cc===node || cc.caseItem===node) {
                    finalResult = srt;
                }
                if (exists i = cc.caseItem) {
                    requiredType = srt;
                    i.visit(this);
                }
                if (exists b = cc.block) {
                    requiredType = ort;
                    b.visit(this);
                }
            }
        }
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.SwitchExpression that) {
        value ort = requiredType;
        Type? srt;
        if (exists switchClause = that.switchClause) {
            switchClause.visit(this);
            if (exists e = switchClause.switched?.expression) {
                srt = e.typeModel;
            } else if (exists v = switchClause.switched?.variable) {
                srt = v.type?.typeModel;
            } else {
                srt = null;
            }
        }
        else {
            srt = null;
        }
        
        if (exists switchCaseList = that.switchCaseList,
            exists caseClauses = switchCaseList.caseClauses) {
            for (cc in caseClauses) {
                if (cc===node || cc.caseItem===node) {
                    finalResult = srt;
                }
                if (exists i = cc.caseItem) {
                    requiredType = srt;
                    i.visit(this);
                }
                if (exists e = cc.expression) {
                    requiredType = ort;
                    e.visit(this);
                }
            }
        }
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.AnnotationList that) {
        value ort = requiredType;
        requiredType = null;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.AttributeDeclaration that) {
        value ort = requiredType;
        requiredType = that.type?.typeModel;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.MethodDeclaration that) {
        value ort = requiredType;
        requiredType = that.type?.typeModel;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.FunctionArgument that) {
        value ort = requiredType;
        requiredType = that.type?.typeModel;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.AssignmentOp that) {
        value ort = requiredType;
        requiredType = that.leftTerm?.typeModel;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.Return that) {
        value ort = requiredType;
        requiredType = types.getResultType(that.declaration);
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.Throw that) {
        value ort = requiredType;
        requiredType = that.unit?.exceptionType;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.ConditionList that) {
        value ort = requiredType;
        requiredType = that.unit?.booleanType;
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.ResourceList that) {
        value ort = requiredType;
        if (exists unit = that.unit) {
            requiredType
                    = ModelUtil.unionType(
                unit.destroyableType,
                unit.obtainableType,
                unit);
        }
        super.visit(that);
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.StringLiteral that) {
        value ort = requiredType;
        super.visit(that); // pass on
        requiredType = ort;
    }

    overloaded
    shared actual void visit(Tree.DocLink that) {
        value ort = requiredType;
        Declaration? base = that.base;
        requiredType = types.getResultType(base);
        if (!exists rt = requiredType, exists base) {
            requiredType = base.reference?.fullType;
        }
        super.visit(that);
        requiredType = ort;
    }
}
