import ceylon.collection {
    MutableList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Reference,
    Scope,
    Functional,
    TypeDeclaration,
    Generic,
    Unit,
    Class,
    Interface,
    Type,
    ModelUtil,
    FunctionOrValue
}

import java.lang {
    JInteger=Integer
}
import java.util {
    Collections
}

shared interface InvocationCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact> 
        given IdeArtifact satisfies Object {
    
    shared formal String inexactMatches;
    
    shared formal Boolean addParameterTypesInCompletions;
    
    shared formal CompletionResult newPositionalInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, IdeComponent cmp,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted, Declaration? qualifyingDec);

    shared formal CompletionResult newNamedInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, IdeComponent cmp,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted);

    shared formal CompletionResult newReferenceCompletion(Integer offset, String prefix, String desc, String text,
        Declaration dec, Unit u, Reference? pr, Scope scope, IdeComponent cmp, Boolean isMember, Boolean includeTypeArgs);
    
    shared formal CompletionResult newParameterInfo(Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, IdeComponent cpc, Boolean namedInvocation);
    
    // see InvocationCompletionProposal.addInvocationProposals()
    shared void addInvocationProposals(
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        String? typeArgs, Boolean isMember) {
        
        if (is Functional fd = dec) {
            value unit = cmp.rootNode.unit;
            value isAbstract = if (is TypeDeclaration dec, dec.abstract) then true else false;
            value pls = fd.parameterLists;
            
            if (!pls.empty) {
                value parameterList = pls.get(0);
                value ps = parameterList.parameters;
                value exact = prefixWithoutTypeArgs(prefix, typeArgs)
                        .equals(dec.getName(unit));
                value positional = exact
                        || "both".equals(inexactMatches)
                        || "positional".equals(inexactMatches);
                value named = exact || "both".equals(inexactMatches);
                
                if (positional, exists pr, 
                    parameterList.positionalParametersSupported,
                    !isAbstract || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                            || isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)) {

                    value parameters = getParameters(parameterList, false, false);
                    if (ps.size() != parameters.size()) {
                        value desc = getPositionalInvocationDescriptionFor(dec, ol, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        value text = getPositionalInvocationTextFor(dec, ol, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newPositionalInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, false, null));
                    }

                    value desc = getPositionalInvocationDescriptionFor(dec, ol, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                    value text = getPositionalInvocationTextFor(dec, ol, pr, unit, true, typeArgs, addParameterTypesInCompletions);

                    result.add(newPositionalInvocationCompletion(offset, prefix, desc, text, dec,
                        pr, scope, cmp, isMember, typeArgs, true, null));
                }
                if (named, parameterList.namedParametersSupported, exists pr,
                    !isAbstract && !isLocation(ol, OccurrenceLocation.\iEXTENDS) 
                            && !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)
                            && !dec.overloaded) {
                    
                    value parameters = getParameters(parameterList, false, true);
                    if (ps.size() != parameters.size()) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        value text =  getNamedInvocationTextFor(dec, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newNamedInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, false));
                    }
                    if (!ps.empty) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                        value text = getNamedInvocationTextFor(dec, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newNamedInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, true));
                    }
                }
            }
        }
    }
    
    // see InvocationCompletionProposal.addReferenceProposal()
    shared void addReferenceProposal(Tree.CompilationUnit cu,
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        Boolean isMember) {
        
        value unit = cu.unit;
        
        //proposal with type args
        if (is Generic dec) {
            value desc = getDescriptionFor(dec, unit);
            value text = getTextFor(dec, unit);
            
            result.add(newReferenceCompletion(offset, prefix, desc, text, dec, unit, pr, scope, cmp, isMember, true));
            
            if (dec.typeParameters.empty) {
                // don't add another proposal below!
                return;
            }
        }
        
        //proposal without type args
        value isAbstract = if (is Class dec) then dec.abstract else dec is Interface;
        if (!isAbstract, !isLocation(ol, OccurrenceLocation.\iEXTENDS),
            !isLocation(ol, OccurrenceLocation.\iSATISFIES),
            !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS),
            !isLocation(ol, OccurrenceLocation.\iTYPE_ALIAS)) {
            
            value desc = dec.getName(unit);
            value text = escaping.escapeName(dec, unit);

            result.add(newReferenceCompletion(offset, prefix, desc, text, dec, unit, pr, scope, cmp, isMember, false));
        }
    }
    
    shared void addFakeShowParametersCompletion(Node node, IdeComponent cpc, MutableList<CompletionResult> result) {
        object extends Visitor() {
            
            shared actual void visit(Tree.InvocationExpression that) {
                Tree.ArgumentList? al = that.positionalArgumentList else that.namedArgumentList;

                if (exists pal=al) {
                    JInteger? startIndex = pal.startIndex;
                    JInteger? startIndex2 = node.startIndex;
                    if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                        if (is Tree.MemberOrTypeExpression primary = that.primary) {
                            if (exists decl = primary.declaration, exists target = primary.target) {
                                result.add(newParameterInfo(startIndex.intValue(), decl, target, node.scope, cpc, pal is Tree.NamedArgumentList));
                            }
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(cpc.rootNode);
    }

    shared void addSecondLevelProposal(Integer offset, String prefix, IdeComponent controller, MutableList<CompletionResult> result,
            Declaration dec, Scope scope, Boolean isMember, Reference pr, Type? requiredType, OccurrenceLocation? ol) {
        
        if (!(dec is Functional), !(dec is TypeDeclaration)) {
            value unit = controller.rootNode.unit;
            value type = pr.type;
            if (ModelUtil.isTypeUnknown(type)) {
                return;
            }
            value members = type.declaration.getMatchingMemberDeclarations(unit, scope, "", 0).values();
            for (ndwp in CeylonIterable(members)) {
                value m = ndwp.declaration;
                if ((m is FunctionOrValue || m is Class), !ModelUtil.isConstructor(m)) {
                    addSecondLevelProposalInternal(offset, prefix, controller, result, dec, scope, requiredType, ol, unit, type, m);
                }
            }
        }
        if (is Class dec) {
            value unit = controller.rootNode.unit;
            value type = pr.type;
            if (ModelUtil.isTypeUnknown(type)) {
                return;
            }
            value members = type.declaration.getMatchingMemberDeclarations(unit, scope, "", 0).values();
            for (ndwp in CeylonIterable(members)) {
                value m = ndwp.declaration;
                if (ModelUtil.isConstructor(m)) {
                    addSecondLevelProposalInternal(offset, prefix, controller, result, dec, scope, requiredType, ol, unit, type, m);
                }
            }
        }
    }

    void addSecondLevelProposalInternal(Integer offset, String prefix, IdeComponent controller, MutableList<CompletionResult> result,
            Declaration dec, Scope scope, Type? requiredType, OccurrenceLocation? ol, Unit unit, Type type, Declaration m) {
        value ptr = type.getTypedReference(m, Collections.emptyList<Type>());
        
        if (exists mt = ptr.type, (requiredType is Null || mt.isSubtypeOf(requiredType))) {
            value qualifier = dec.name + ".";
            value desc = qualifier + getPositionalInvocationDescriptionFor(m, ol, ptr, unit, false, null, addParameterTypesInCompletions);
            value text = qualifier + getPositionalInvocationTextFor(m, ol, ptr, unit, false, null, addParameterTypesInCompletions);
            result.add(newPositionalInvocationCompletion(offset, prefix, desc, text, m, ptr, scope, controller, true, null, true, dec));
        }
    }

    // see InvocationCompletionProposal.prefixWithoutTypeArgs
    String prefixWithoutTypeArgs(String prefix, String? typeArgs) {
        if (exists typeArgs) {
            return prefix.span(0, prefix.size - typeArgs.size);
        } else {
            return prefix;
        }
    }
}