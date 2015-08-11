import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation
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
    Interface
}

shared interface InvocationCompletion<IdeComponent,CompletionComponent> {
    
    shared formal String inexactMatches;
    
    shared formal CompletionComponent newPositionalInvocationCompletion(Integer offset, String prefix,
        Declaration dec, Reference? pr, Scope scope, IdeComponent cmp, Boolean isMember,
        OccurrenceLocation? ol, String? typeArgs, Boolean includeDefaulted);

    shared formal CompletionComponent newNamedInvocationCompletion(Integer offset, String prefix,
        Declaration dec, Reference? pr, Scope scope, IdeComponent cmp, Boolean isMember,
        OccurrenceLocation? ol, String? typeArgs, Boolean includeDefaulted);

    shared formal CompletionComponent newReferenceCompletion(Integer offset, String prefix,
        Declaration dec, Unit u, Reference? pr, Scope scope, IdeComponent cmp, Boolean isMember, Boolean includeTypeArgs);
    
    // see InvocationCompletionProposal.addInvocationProposals()
    shared void addInvocationProposals(Tree.CompilationUnit cu,
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionComponent> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        String? typeArgs, Boolean isMember) {
        
        if (is Functional fd = dec) {
            value unit = cu.unit;
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
                
                if (positional, parameterList.positionalParametersSupported,
                    !isAbstract || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                            || isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)) {

                    value parameters = getParameters(parameterList, false, false);
                    if (ps.size() != parameters.size()) {
                        result.add(newPositionalInvocationCompletion(offset, prefix, dec, pr, scope, 
                            cmp, isMember, ol, typeArgs, false));
                    }

                    result.add(newPositionalInvocationCompletion(offset, prefix, dec, pr, scope, 
                        cmp, isMember, ol, typeArgs, true));
                }
                if (named, parameterList.namedParametersSupported,
                    !isAbstract && !isLocation(ol, OccurrenceLocation.\iEXTENDS) 
                            && !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)
                            && !dec.overloaded) {
                    
                    value parameters = getParameters(parameterList, false, true);
                    if (ps.size() != parameters.size()) {
                        result.add(newNamedInvocationCompletion(offset, prefix, dec, pr, scope, 
                            cmp, isMember, ol, typeArgs, false));
                    }
                    if (!ps.empty) {
                        result.add(newNamedInvocationCompletion(offset, prefix, dec, pr, scope, 
                            cmp, isMember, ol, typeArgs, true));
                    }
                }
            }
        }
    }
    
    // see InvocationCompletionProposal.addReferenceProposal()
    shared void addReferenceProposal(Tree.CompilationUnit cu,
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionComponent> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        Boolean isMember) {
        
        value unit = cu.unit;
        
        //proposal with type args
        if (is Generic dec) {
            result.add(newReferenceCompletion(0, prefix, dec, unit, pr, scope, cmp, isMember, true));
            
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
            
            result.add(newReferenceCompletion(0, prefix, dec, unit, pr, scope, cmp, isMember, false));
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