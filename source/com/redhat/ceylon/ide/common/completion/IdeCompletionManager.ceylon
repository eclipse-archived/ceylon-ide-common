import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    Scope,
    Type,
    TypeDeclaration,
    Declaration,
    Class,
    TypedDeclaration,
    ImportList,
    Unit,
    ModelUtil {
        isTypeUnknown
    },
    Function
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import java.lang {
    JString=String
}
import java.util {
    Map,
    HashMap
}
import ceylon.interop.java {
    CeylonIterable
}

shared abstract class IdeCompletionManager() {

    value emptyMap = HashMap<JString,DeclarationWithProximity>();
    
    shared alias Proposals => Map<JString,DeclarationWithProximity>;
    
    shared Proposals getProposals(Node node, Scope? scope, String prefix,
        Boolean memberOp, Tree.CompilationUnit rootNode) {
        
        Unit? unit = node.unit;
        
        if (!exists unit) {
            return emptyMap;
        }
        
        assert (exists unit);
        
        if (is Tree.MemberLiteral node) {
            if (exists mlt = node.type) {
                if (exists type = mlt.typeModel) {
                    return type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                        unit, scope, prefix, 0);
                } else {
                    return emptyMap;
                }
            }
        } else if (is Tree.TypeLiteral node) {
            if (exists bt = node.type, is Tree.BaseType bt) {
                if (bt.packageQualified) {
                    return unit.\ipackage
                        .getMatchingDirectDeclarations(
                        prefix, 0);
                }
            }
            if (exists tlt = node.type, exists type = tlt.typeModel) {
                return type.resolveAliases()
                    .declaration
                    .getMatchingMemberDeclarations(
                    unit, scope, prefix, 0);
            } else {
                return emptyMap;
            }
        }
        
        if (is Tree.QualifiedMemberOrTypeExpression node) {
            variable Type? type = getPrimaryType(node);
            
            if (node.staticMethodReference) {
                type = unit.getCallableReturnType(type);
            }
            
            if (exists t = type, !t.unknown) {
                return t.resolveAliases().declaration
                    .getMatchingMemberDeclarations(unit, scope, prefix, 0);
            } else {
                value primary = node.primary;
                
                if (is Tree.MemberOrTypeExpression primary, is TypeDeclaration td = primary.declaration) {
                    if (exists t = td.type) {
                        return t.resolveAliases()
                            .declaration
                            .getMatchingMemberDeclarations(unit, scope, prefix, 0);
                    }
                } else if (is Tree.Package primary) {
                    return unit.\ipackage
                            .getMatchingDirectDeclarations(prefix, 0);    
                }
            }
            
            return emptyMap;
        } else if (is Tree.QualifiedType node) {
            if (exists t = node.outerType.typeModel) {
                return t.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(unit, scope, prefix, 0);
            } else {
                return emptyMap;
            }
        } else if (is Tree.BaseType node) {
            if (node.packageQualified) {
                return unit.\ipackage.getMatchingDirectDeclarations(prefix, 0);
            } else if (exists scope) {
                return scope.getMatchingDeclarations(unit, prefix, 0);
            } else {
                return emptyMap;
            }
        } else if (memberOp, is Tree.Term|Tree.DocLink node) {
            variable Type? type = null;
            
            if (is Tree.DocLink node) {
                if (exists d = node.base) {
                    type = getResultType(d) else d.reference.fullType;
                }
            } else {
                type = node.typeModel;
            }
            
            if (exists t = type) {
                return t.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(unit, scope, prefix, 0);
            } else {
                return scope?.getMatchingDeclarations(unit, prefix, 0) else emptyMap;
            }
        } else {
            if (is ImportList scope) {
                return scope.getMatchingDeclarations(unit, prefix, 0);
            } else {
                return scope?.getMatchingDeclarations(unit, prefix, 0) else getUnparsedProposals(rootNode, prefix);
            }
        }
    }
    
    shared Proposals getFunctionProposals(Node node, Scope scope, String prefix, Boolean memberOp) {
        value unit = node.unit;
        
        if (is Tree.QualifiedMemberOrTypeExpression node, exists type = getPrimaryType(node), 
            !node.staticMethodReference, !isTypeUnknown(type)) {
            return collectUnaryFunctions(type, scope.getMatchingDeclarations(unit, "", 0));
        } else if (memberOp, is Tree.Term node, exists type = node.typeModel) {
            return collectUnaryFunctions(type, scope.getMatchingDeclarations(unit, "", 0));
        }
        
        return emptyMap;
    }
    
    Proposals collectUnaryFunctions(Type type, Proposals candidates) {
        Proposals matches = HashMap<JString,DeclarationWithProximity>();
        
        CeylonIterable(candidates.entrySet()).each(void (candidate) {
            if (is Function declaration = candidate.\ivalue.declaration, !declaration.annotation) {
                if (!declaration.parameterLists.empty) {
                    value params = declaration.firstParameterList.parameters;
                    
                    if (!params.empty) {
                        variable Boolean unary = true;
                        if (params.size() > 1) {
                            for (i in 1..params.size()-1) {
                                if (!params.get(i).defaulted) {
                                    unary = false;
                                }
                            }
                        }
                        
                        value t = params.get(0).type;
                        if (unary, !isTypeUnknown(t), type.isSubtypeOf(t)) {
                            matches.put(candidate.key, candidate.\ivalue);
                        }
                    }
                }
            }
        });
        
        return matches;
    }
    
    Type? getPrimaryType(Tree.QualifiedMemberOrTypeExpression qme) {
        Type? type = qme.primary.typeModel;
        
        if (exists type) {
            value mo = qme.memberOperator;
            value unit = qme.unit;
            
            if (is Tree.SafeMemberOp mo) {
                return unit.getDefiniteType(type);
            } else if (is Tree.SpreadOp mo) {
                return unit.getIteratedType(type);
            } else {
                return type;
            }
        }
        
        return null;
    }
    
    Type? getResultType(Declaration d) {
        if (is TypeDeclaration d) {
            if (is Class d) {
                if (!d.abstract) {
                    return d.type;
                }
            }
        } else if (is TypedDeclaration d) {
            return d.type;
        }
        
        return null;
    }
    
    Map<JString, DeclarationWithProximity> getUnparsedProposals(Node? node, String prefix) {
        if (exists node) {
            value pkg = node.unit?.\ipackage;
            
            if (exists pkg) {
                return pkg.\imodule.getAvailableDeclarations(prefix);
            }
        }
        
        return emptyMap;
    }
    
    shared Boolean isQualifiedType(Node node) {
        if (is Tree.QualifiedType node) {
            return true;
        } else if (is Tree.QualifiedMemberOrTypeExpression node) {
            return node.staticMethodReference;
        }
        
        return false;
    }
}

shared class FindScopeVisitor(Node node) extends Visitor() {
    variable Scope? myScope = null;

    shared Scope? scope => myScope else node.scope;

    shared actual void visit(Tree.Declaration that) {
        super.visit(that);
        
        if (exists al = that.annotationList) {
            for (ann in CeylonIterable(al.annotations)) {
                if (ann.primary.startIndex.equals(node.startIndex)) {
                    myScope = that.declarationModel.scope;
                }
            }
        }
    }

    shared actual void visit(Tree.DocLink that) {
        super.visit(that);
        
        if (is Tree.DocLink node) {
            myScope = node.pkg;
        }
    }
}