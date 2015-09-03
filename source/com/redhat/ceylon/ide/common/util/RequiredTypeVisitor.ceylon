import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Functional,
    Parameter,
    ParameterList,
    Reference,
    Type,
    Unit,
    ModelUtil
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken,
    Token
}

class RequiredTypeVisitor extends Visitor {
    
    variable Node node;
    variable Type? requiredType = null;
    variable Type? finalResult = null;
    variable Reference? namedArgTarget = null;
    variable Token? token;

    shared Type? type => finalResult;

    shared new (variable Node node, variable Token token) extends Visitor() {
        this.node = node;
        this.token = token;
    }

    shared actual void visitAny(variable Node that) {
        if (node === that) {
            finalResult = requiredType;
        }
        super.visitAny(that);
    }
    
    shared actual void visit(Tree.InvocationExpression that) {
        if (exists p = that.primary) {
            p.visit(this);
        }
        Type? ort = requiredType;
        Reference? onat = namedArgTarget;
        Tree.PositionalArgumentList? pal = that.positionalArgumentList;
        Unit unit = that.unit;

        if (exists pal) {
            variable Integer pos;
            variable List<Tree.PositionalArgument> pas = pal.positionalArguments;
            if (pas.empty) {
                pos = 0;
            } else {
                pos = pas.size(); //default to the last argument if incomplete
                variable Integer i = 0;
                while (i < pas.size()) {
                    variable Tree.PositionalArgument pa = pas.get(i);
                    if (exists t = token) {
                        assert(is CommonToken t);
                        if (pa.stopIndex.intValue() >= t.stopIndex) {
                            pos = i;
                            break;
                        }
                    } else {
                        if (node.startIndex.intValue() >= pa.startIndex.intValue(), node.stopIndex.intValue() <= pa.stopIndex.intValue()) {
                            pos = i;
                            break;
                        }
                    }
                    i++;
                }
            }

            if (exists pr = getTarget(that), exists params = getParameters(pr)) {
                if (params.size() > pos) {
                    Parameter param = params.get(pos);
                    if (pr.declaration.qualifiedNameString.equals("ceylon.language::print")) {
                        requiredType = unit.stringDeclaration.type;
                    } else {
                        requiredType = pr.getTypedParameter(param).fullType;
                        if (param.sequenced) {
                            requiredType = unit.getIteratedType(requiredType);
                        }
                    }
                } else if (!params.empty) {
                    Parameter param = params.get(params.size() - 1);
                    if (param.sequenced) {
                        requiredType = pr.getTypedParameter(param).fullType;
                        requiredType = unit.getIteratedType(requiredType);
                    }
                }
            }
        }

        Tree.NamedArgumentList? nal = that.namedArgumentList;
        if (exists nal) {
            namedArgTarget = getTarget(that);
            if (exists nat = namedArgTarget, exists params = getParameters(nat), !params.empty) {
                Parameter param = params.get(params.size() - 1);
                if (unit.isIterableType(param.type)) {
                    requiredType = nat.getTypedParameter(param).fullType;
                    requiredType = unit.getIteratedType(requiredType);
                }
            }
        }
        if (node===that.positionalArgumentList || node===that.namedArgumentList) {
            finalResult = requiredType;
        }
        if (exists nal) {
            nal.visit(this);
        }
        if (exists pal) {
            pal.visit(this);
        }
        requiredType = ort;
        namedArgTarget = onat;
    }

    Reference? getTarget(variable Tree.InvocationExpression that) {
        if (is Tree.MemberOrTypeExpression p = that.primary) {
            return p.target;
        } else {
            return null;
        }
    }
    
    List<Parameter>? getParameters(Reference pr) {
        if (is Functional declaration = pr.declaration) {
            List<ParameterList> pls = declaration.parameterLists;
            return if (pls.empty) then null else pls.get(0).parameters;
        } else {
            return null;
        }
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        Type? ort = requiredType;
        Parameter? p = that.parameter;
        if (exists p) {
            if (exists nat = namedArgTarget) {
                requiredType = nat.getTypedParameter(p).type;
            } else {
                requiredType = p.type;
            }
        }
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.ForIterator that) {
        Type? ort = requiredType;
        requiredType = that.unit.getIterableType(that.unit.anythingDeclaration.type);
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.SpecifierStatement that) {
        Type? ort = requiredType;
        requiredType = that.baseMemberExpression.typeModel;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.SwitchStatement that) {
        Type? ort = requiredType;
        variable Type? srt = that.unit.anythingDeclaration.type;
        if (exists switchClause = that.switchClause) {
            switchClause.visit(this);
            Tree.Expression? e = switchClause.switched.expression;
            Tree.Variable? v = switchClause.switched.variable;
            if (exists e) {
                srt = e.typeModel;
            } else if (exists v) {
                srt = v.type.typeModel;
            } else {
                srt = null;
            }
        }

        if (exists switchCaseList = that.switchCaseList) {
            for (Tree.CaseClause cc in CeylonIterable(switchCaseList.caseClauses)) {
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
    
    shared actual void visit(Tree.AnnotationList that) {
        Type? ort = requiredType;
        requiredType = null;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.AttributeDeclaration that) {
        Type? ort = requiredType;
        requiredType = that.type.typeModel;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.MethodDeclaration that) {
        Type? ort = requiredType;
        requiredType = that.type.typeModel;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.FunctionArgument that) {
        Type? ort = requiredType;
        requiredType = that.type.typeModel;
        super.visit(that);
        requiredType = ort;
    }
    shared actual void visit(Tree.AssignmentOp that) {
        Type? ort = requiredType;
        requiredType = that.leftTerm.typeModel;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.Return that) {
        Type? ort = requiredType;
        requiredType = types.getResultType(that.declaration);
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.Throw that) {
        Type? ort = requiredType;
        requiredType = that.unit.exceptionDeclaration.type;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.ConditionList that) {
        Type? ort = requiredType;
        requiredType = that.unit.booleanDeclaration.type;
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.ResourceList that) {
        Type? ort = requiredType;
        Unit unit = that.unit;
        requiredType = ModelUtil.unionType(unit.destroyableDeclaration.type,
            unit.obtainableDeclaration.type, unit);
        super.visit(that);
        requiredType = ort;
    }
    
    shared actual void visit(Tree.StringLiteral that) {
        Type? ort = requiredType;
        super.visit(that); // pass on
        requiredType = ort;
    }
    
    shared actual void visit(Tree.DocLink that) {
        Type? ort = requiredType;
        requiredType = types.getResultType(that.base);
        if (!exists rt = requiredType, exists b = that.base) {
            requiredType = b.reference.fullType;
        }
        super.visit(that);
        requiredType = ort;
    }
}
