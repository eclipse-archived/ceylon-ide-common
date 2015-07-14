import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    Scope,
    Type,
    TypeDeclaration,
    Declaration,
    Class,
    TypedDeclaration,
    Unit,
    ModelUtil {
        isTypeUnknown
    },
    Function
}

import java.lang {
    JString=String
}
import java.util {
    Map,
    HashMap
}

shared abstract class IdeCompletionManager() {

    shared alias Proposals 
            => Map<JString,DeclarationWithProximity>;
    
    Proposals noProposals
            = HashMap<JString,DeclarationWithProximity>();
    
    shared Proposals getProposals(
            Node node, Scope? scope, 
            String prefix, Boolean memberOp, 
            Tree.CompilationUnit rootNode) {
        
        Unit? unit = node.unit;
        
        if (!exists unit) {
            return noProposals;
        }
        
        assert (exists unit);
        
        switch (node)
        case (is Tree.MemberLiteral) {
            if (exists mlt = node.type) {
                return if (exists type = mlt.typeModel) 
                    then type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0) 
                    else noProposals;
            }
        } case (is Tree.TypeLiteral) {
            if (is Tree.BaseType bt = node.type) {
                if (bt.packageQualified) {
                    return unit.\ipackage
                        .getMatchingDirectDeclarations(
                            prefix, 0);
                }
            }
            if (exists tlt = node.type) {
                return if (exists type = tlt.typeModel) 
                    then type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0) 
                    else noProposals;
            }
        }
        else {}
        
        switch (node)
        case (is Tree.QualifiedMemberOrTypeExpression) {
            value type = let (pt = getPrimaryType(node)) 
                if (node.staticMethodReference) 
                    then unit.getCallableReturnType(pt) 
                    else pt;
            
            if (exists type, !type.unknown) {
                return type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0);
            } else {
                switch (primary = node.primary)
                case (is Tree.MemberOrTypeExpression) { 
                    if (is TypeDeclaration td 
                            = primary.declaration) {
                        return if (exists t = td.type) 
                            then t.resolveAliases()
                                .declaration
                                .getMatchingMemberDeclarations(
                                    unit, scope, prefix, 0) 
                            else noProposals;
                    } else {
                        return noProposals;
                    }
                } case (is Tree.Package) {
                    return unit.\ipackage
                            .getMatchingDirectDeclarations(
                                prefix, 0);    
                } else {
                    return noProposals;
                }
            }            
        } case (is Tree.QualifiedType) {
            if (exists qt = node.outerType.typeModel) {
                return qt.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0);
            } else {
                return noProposals;
            }
        } case (is Tree.BaseType) {
            if (node.packageQualified) {
                return unit.\ipackage
                        .getMatchingDirectDeclarations(
                            prefix, 0);
            } else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0);
            } else {
                return noProposals;
            }
        } else {
            if (memberOp, is Tree.Term|Tree.DocLink node) {
                Type? type;
                if (is Tree.DocLink node) {
                    if (exists d = node.base) {
                        type = getResultType(d) 
                            else d.reference.fullType;
                    }
                    else {
                        type = null;
                    }
                } else {
                    type = node.typeModel;
                }
                
                if (exists type) {
                    return type.resolveAliases()
                            .declaration
                            .getMatchingMemberDeclarations(
                                unit, scope, prefix, 0);
                } else if (exists scope) {
                    return scope.getMatchingDeclarations(
                        unit, prefix, 0);
                } else { 
                    return noProposals;
                }
            } else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0);
            }
            else { 
                return getUnparsedProposals(
                    rootNode, prefix);
            }
        }
    }
    
    shared Proposals getFunctionProposals(
            Node node, Scope scope,
            String prefix, Boolean memberOp) {
        value unit = node.unit;
        if (is Tree.QualifiedMemberOrTypeExpression node,
            exists type = getPrimaryType(node),
            !node.staticMethodReference,
            !isTypeUnknown(type)) {
            return collectUnaryFunctions(type, 
                scope.getMatchingDeclarations(unit, "", 0));
        } else if (memberOp, 
            is Tree.Term node,
            exists type = node.typeModel) {
            return collectUnaryFunctions(type, 
                scope.getMatchingDeclarations(unit, "", 0));
        }
        else {
            return noProposals;
        }
    }
    
    Proposals collectUnaryFunctions(Type type, 
            Proposals candidates) {
        value matches 
                = HashMap<JString,DeclarationWithProximity>();
        
        CeylonIterable(candidates.entrySet())
                .each(void (candidate) {
            if (is Function declaration 
                    = candidate.\ivalue.declaration, 
                !declaration.annotation, 
                !declaration.parameterLists.empty) {
                
                value params = 
                        declaration.firstParameterList
                            .parameters;
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
                    if (unary, 
                            !isTypeUnknown(t), 
                            type.isSubtypeOf(t)) {
                        matches.put(candidate.key, 
                            candidate.\ivalue);
                    }
                }
            }
        });
        
        return matches;
    }
    
    Type? getPrimaryType(
            Tree.QualifiedMemberOrTypeExpression qme) {
        if (exists type = qme.primary.typeModel) {
            value unit = qme.unit;
            return switch (mo = qme.memberOperator)
                case (is Tree.SafeMemberOp)
                    unit.getDefiniteType(type)
                case (is Tree.SpreadOp)
                    unit.getIteratedType(type)
                else type;
        }
        else {
            return null;
        }
    }
    
    Type? getResultType(Declaration d) {
        switch (d)
        case (is TypedDeclaration) {
            return d.type;
        }
        case (is TypeDeclaration) {
            if (is Class d) {
                if (!d.abstract) {
                    return d.type;
                }
            }
            return null;
        }
        else {
            return null;
        }
    }
    
    Proposals getUnparsedProposals(Node? node, String prefix) 
            => if (exists node, 
                    exists pkg = node.unit?.\ipackage)
                then pkg.\imodule
                    .getAvailableDeclarations(prefix)
                else noProposals;
    
    shared Boolean isQualifiedType(Node node) 
            => if (is Tree.QualifiedMemberOrTypeExpression node) 
                then node.staticMethodReference 
                else node is Tree.QualifiedType;
}

shared class FindScopeVisitor(Node node) extends Visitor() {
    variable Scope? myScope = null;

    shared Scope? scope => myScope else node.scope;

    shared actual void visit(Tree.Declaration that) {
        super.visit(that);
        
        if (exists al = that.annotationList) {
            for (ann in CeylonIterable(al.annotations)) {
                if (ann.primary.startIndex==node.startIndex) {
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