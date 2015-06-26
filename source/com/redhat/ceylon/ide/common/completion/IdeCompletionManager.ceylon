import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    Scope,
    Type,
    TypeDeclaration,
    Declaration,
    Class,
    TypedDeclaration,
    ImportList
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import java.lang {
    JString=String
}
import java.util {
    Map,
    HashMap
}

shared abstract class IdeCompletionManager() {

    value emptyMap = HashMap<JString,DeclarationWithProximity>();
    
    shared Map<JString,DeclarationWithProximity> getProposals(Node node, Scope? scope, String prefix,
        Boolean memberOp, Tree.CompilationUnit rootNode) {
        
        value unit = node.unit;
        
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
                    return (d of TypeDeclaration).type;
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
}
