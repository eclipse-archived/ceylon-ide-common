import ceylon.collection {
    ArrayList,
    MutableList
}
import ceylon.interop.java {
    CeylonIterable,
    createJavaObjectArray
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    OccurrenceLocation
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
    Function,
    Reference,
    Generic,
    TypeParameter,
    FunctionOrValue,
    ClassOrInterface
}

import java.lang {
    JString=String,
    ObjectArray
}
import java.util {
    Map,
    HashMap,
    JList=List,
    Collection,
    Collections,
    JArrayList=ArrayList
}

import org.antlr.runtime {
    CommonToken,
    Token
}

shared abstract class IdeCompletionManager<IdeComponent, CompletionComponent, Document>() 
        satisfies InvocationCompletion<IdeComponent, CompletionComponent>
                & ParametersCompletion<IdeComponent, CompletionComponent>
                & MemberNameCompletion<IdeComponent, CompletionComponent>
                & RefinementCompletion<IdeComponent, CompletionComponent, Document>
        given CompletionComponent satisfies Object {

    shared alias Proposals
            => Map<JString,DeclarationWithProximity>;

    Proposals noProposals
            = HashMap<JString,DeclarationWithProximity>();

    shared formal String getDocumentSubstring(Document doc, Integer start, Integer length);
    
    shared Proposals getProposals(Node node, 
            Scope? scope, String prefix, Boolean memberOp,
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
                value type = switch (node)
                    case (is Tree.Term)
                        node.typeModel
                    case (is Tree.DocLink)
                        docLinkType(node);

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

    Type? getFunctionProposalType(Node node, 
            Boolean memberOp) {
        if (is Tree.QualifiedMemberOrTypeExpression node,
            !node.staticMethodReference,
            exists type = getPrimaryType(node)) {
            return type;
        }
        else if (memberOp,
            is Tree.Term node,
            exists type = node.typeModel) {
            return type;
        }
        else {
            return null;
        }
    }
    
    shared Proposals getFunctionProposals(Node node, 
            Scope scope, String prefix, Boolean memberOp) 
            => if (exists type 
                    = getFunctionProposalType(node, memberOp), 
                    !isTypeUnknown(type)) 
            then collectUnaryFunctions(type,
                scope.getMatchingDeclarations(node.unit, 
                    prefix, 0))
            else noProposals;
    
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

                    Type? t = params.get(0).type;
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

    Type? docLinkType(Tree.DocLink node) {
        if (exists base = node.base) {
            return resultType(base)
                else base.reference.fullType;
        }
        else {
            return null;
        }
    }

    Type? resultType(Declaration declaration) {
        switch (declaration)
        case (is TypedDeclaration) {
            return declaration.type;
        }
        case (is TypeDeclaration) {
            if (is Class declaration) {
                if (!declaration.abstract) {
                    return declaration.type;
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
    
    // see CeylonCompletionProcess.constructCompletions(...)
    shared ObjectArray<CompletionComponent> constructCompletions(Integer offset, String prefix,
            Collection<DeclarationWithProximity> sortedProposals, 
            Collection<DeclarationWithProximity> sortedFunctionProposals, 
            IdeComponent cmp, Scope scope, 
            Node node, CommonToken? token, 
            Boolean memberOp, Document doc, 
            Boolean secondLevel, Boolean inDoc,
            Type? requiredType, Integer previousTokenType, 
            Integer tokenType) {
        
        MutableList<CompletionComponent> result = ArrayList<CompletionComponent>();
        value cu = getCompilationUnit(cmp); 
        value ol = nodes.getOccurrenceLocation(cu, node, offset);
        value unit = node.unit;
        
        if (is Tree.Term node) {
            addParametersProposal(offset, node, result, cmp);
        } else if (is Tree.ArgumentList node) {
            value fiv = FindInvocationVisitor(node);
            (fiv of Visitor).visit(cu);
            
            if (exists ie = fiv.result) {
                addParametersProposal(offset, ie, result, cmp);
            }
        }
        
        if (is Tree.TypeConstraint node) {
            for (dwp in CeylonIterable(sortedProposals)) {
                value dec = dwp.declaration;
                if (isTypeParameterOfCurrentDeclaration(node, dec)) {
                    addReferenceProposal(cu, offset, prefix, cmp, 
                        result, dec, null, scope, ol, false);
                }           
            }
        } else if (prefix.empty, !isLocation(ol, OccurrenceLocation.\iIS),
                isMemberNameProposable(offset, node, memberOp),
                node is Tree.Type || node is Tree.BaseTypeExpression || node is Tree.QualifiedTypeExpression) {
            Type? t = switch (node)
                case (is Tree.Type) node.typeModel
                case (is Tree.BaseTypeExpression) node.target?.type
                case (is Tree.QualifiedTypeExpression) node.target?.type
                else null;
            
            if (exists t) {
                addRefinementProposals(offset, 
                        sortedProposals, cmp, scope, node, doc,
                        secondLevel, result, ol, t, false);
            }
            //otherwise guess something from the type
            addMemberNameProposal(offset, prefix, node, result);
        } else {
            value isMember = if (is Tree.MemberLiteral node)
                then node.type exists 
                else node is Tree.QualifiedMemberOrTypeExpression || node is Tree.QualifiedType;
            
            if (!secondLevel, !inDoc, !memberOp) {
                // TODO
            }
            if (!secondLevel, !inDoc, !isMember,
                prefix.empty, !ModelUtil.isTypeUnknown(requiredType), unit.isCallableType(requiredType)) {
                // TODO
            }
            
            value isPackageOrModuleDescriptor = false; // TODO
            
            for (dwp in CeylonIterable(sortedProposals)) {
                value dec = dwp.declaration;
                
                if (!dec.toplevel, !dec.classOrInterfaceMember, dec.unit.equals(unit)) {
                    // TODO
                }
                
                if (isPackageOrModuleDescriptor, !inDoc, !isLocation(ol, OccurrenceLocation.\iMETA),
                    !(ol?.reference else false),
                    !dec.annotation || !(dec is Function)) {
                    continue;
                }
                
                value noParamsFollow = true; // TODO
                
                if (!secondLevel, !inDoc, noParamsFollow) {
                    for (d in overloads(dec)) {
                        value pr = if (isMember)
                            then getQualifiedProducedReference(node, dec)
                            else getRefinedProducedReference(scope, dec);
                        
                        addInvocationProposals(cu, offset, prefix, cmp, result, dec, pr, scope, ol, null, isMember);
                    }
                }
                if (true) {
                    if (isLocation(ol, OccurrenceLocation.\iDOCLINK)) {
                        
                    } else if (isLocation(ol, OccurrenceLocation.\iIMPORT)) {
                        
                    } else if (ol?.reference else false) {
                        
                    } else {
                        value pr = if (isMember)
                            then getQualifiedProducedReference(node, dec)
                            else getRefinedProducedReference(scope, dec);
                        
                        if (secondLevel) {
                            // TODO
                        } else if (!dec is Function || !ModelUtil.isAbstraction(dec) || !noParamsFollow) {
                            addReferenceProposal(cu, offset, prefix, cmp, result, dec, pr, scope, ol, isMember);
                        }
                    }
                }
            }
            
        }
        
        
        return createJavaObjectArray(result.sequence());
    }
    
    // see CompletionUtil.overloads(Declaration dec)
    {Declaration*} overloads(Declaration dec) {
        return if (dec.abstraction)
            then CeylonIterable(dec.overloads)
            else {dec};
    }
    
    // see CeylonParseController.isMemberNameProposable(int offset, Node node, boolean memberOp)
    Boolean isMemberNameProposable(Integer offset, 
        Node node, Boolean memberOp) {
        Token? token = node.endToken;

        return if(is CommonToken token, !memberOp,
            token.stopIndex >= offset-2) then true else false;
    }
    
    shared formal Tree.CompilationUnit getCompilationUnit(IdeComponent cmp);
     
    // see CompletionUtil.anonFunctionHeader(Type requiredType, Unit unit)
    shared String anonFunctionHeader(Type requiredType, Unit unit) {
        value text = StringBuilder();
        text.append("(");
        
        variable Character c = 'a';
        
        CeylonIterable(unit.getCallableArgumentTypes(requiredType)).fold(true)((isFirst, paramType) {
            if (!isFirst) { text.append(", "); }
            text.append(paramType.asSourceCodeString(unit))
                .append(" ")
                .append(c.string);
            c++;
            
            return false;
        });
        text.append(")");
        
        return text.string;
    }
    
    Reference? getQualifiedProducedReference(Node node, Declaration d) {
        variable Type? pt;
        
        if (is Tree.QualifiedMemberOrTypeExpression node) {
            pt = node.primary.typeModel;
        } else if (is Tree.QualifiedType node) {
            pt = node.outerType.typeModel;
        } else {
            return null;
        }

        if (exists p = pt, d.classOrInterfaceMember, is TypeDeclaration container = d.container) {
            pt = p.getSupertype(container);
        }
        
        return d.appliedReference(pt, Collections.emptyList<Type>());
    }
    
    Reference? getRefinedProducedReference(Type|Scope typeOrScope, Declaration d) {
        if (is Type typeOrScope) {
            value superType = typeOrScope;
            if (superType.intersection) {
                for (pt in CeylonIterable(superType.satisfiedTypes)) {
                    Reference? result = getRefinedProducedReference(pt, d);
                    if (exists result) {
                        return result;
                    }
                }
                return null; //never happens?
            }
            else {
                if (exists declaringType = superType.declaration.getDeclaringType(d)) {
                    Type outerType = superType.getSupertype(declaringType.declaration);
                    return refinedProducedReference(outerType, d);
                }
                return null;
            }
        } else {
            Type? outerType = typeOrScope.getDeclaringType(d);
            JList<Type> params = JArrayList<Type>();
            if (is Generic d) {
                CeylonIterable(d.typeParameters).each(void (tp) => params.add(tp.type));
            }
            return d.appliedReference(outerType, params);
        }
    }
    
    Reference refinedProducedReference(Type outerType, Declaration d) {
        JList<Type> params = JArrayList<Type>();
        if (is Generic d) {
            for (tp in CeylonIterable(d.typeParameters)) {
                params.add(tp.type);
            }
        }
        return d.appliedReference(outerType, params);
    }
    
    Boolean isTypeParameterOfCurrentDeclaration(Node node, Declaration d) {
        //TODO: this is a total mess and totally error-prone 
        //       - figure out something better!
        if (is TypeParameter tp = d) { 
            Scope tpc = tp.container;
            if (tpc==node.scope) {
                return true;
            }
            else if (is Tree.TypeConstraint constraint = node){
                return if (exists tcp = constraint.declarationModel, tpc==tcp.container) then true else false;
            }
        }

        return false;
    }
    
    void addRefinementProposals(Integer offset,
        Collection<DeclarationWithProximity> set, 
        IdeComponent cpc, Scope scope, 
        Node node, Document doc, Boolean filter,
        MutableList<CompletionComponent> result, 
        OccurrenceLocation? ol, Type t, 
        Boolean preamble) {
        
        for (dwp in CeylonIterable(set)) {
            value dec = dwp.declaration;
            if (!filter, is FunctionOrValue m = dec) {
                for (d in overloads(dec)) {
                    if (isRefinementProposable(d, ol, scope),
                        t.isSubtypeOf(m.type), is ClassOrInterface scope) {
                        value start = node.startIndex.intValue();
                        String pfx = getDocumentSubstring(doc, 0, offset - start);

                        addRefinementProposal(offset, d, 
                            scope, 
                            node, scope, pfx, 
                            cpc, doc, result, preamble);
                    }
                }
            }
        }
    }
    
    Boolean isRefinementProposable(Declaration dec, OccurrenceLocation? ol, Scope scope) {
        return ol is Null && 
                (dec.default || dec.formal) &&
                (dec is FunctionOrValue || dec is Class) && 
                (if (is ClassOrInterface scope) then scope.isInheritedFromSupertype(dec) else false);
    }
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