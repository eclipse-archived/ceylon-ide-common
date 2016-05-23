import com.redhat.ceylon.cmr.api {
    ModuleSearchResult {
        ModuleDetails
    },
    ModuleVersionDetails
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    CompletionContext,
    ProposalsHolder
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Scope,
    Reference,
    Unit,
    Type,
    Package
}

import java.util {
    List
}

shared interface CompletionServices {
    
    shared formal void newBasicCompletionProposal(CompletionContext ctx, Integer offset,
        String prefix, String text, String escapedText, Declaration decl);

    shared default void newInvocationCompletion(CompletionContext ctx, Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope,
        Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation, 
        Boolean inheritance, Boolean qualified, Declaration? qualifyingDec)
            => newBasicCompletionProposal(ctx, offset, prefix, desc, text, dec);
    
    shared formal void newParameterInfo(CompletionContext ctx, Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, Boolean namedInvocation);
    
    shared formal void newParametersCompletionProposal(CompletionContext ctx, Integer offset,
        String prefix, String desc, String text, List<Type> argTypes, Node node, Unit unit);

    shared formal void newKeywordCompletionProposal(CompletionContext ctx,
        Integer offset, String prefix, String keyword, String text);
    
    shared formal void newMemberNameCompletionProposal(CompletionContext ctx,
        Integer offset, String prefix, String name, String unquotedName);
    
    shared formal void newRefinementCompletionProposal(Integer offset, 
        String prefix, Reference? pr, String desc, String text, CompletionContext cmp,
        Declaration dec, Scope scope, Boolean fullType, Boolean explicitReturnType);

    
    shared formal void newPackageDescriptorProposal(CompletionContext ctx, 
        Integer offset, String prefix, String desc, String text);
    
    shared formal void newCurrentPackageProposal(Integer offset, String prefix,
        String packageName, CompletionContext cmp);
    
    shared formal void newImportedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, CompletionContext controller,
        Package candidate);
    
    shared formal void newQueriedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, CompletionContext controller,
        ModuleVersionDetails version, Unit unit, ModuleSearchResult.ModuleDetails md);

    shared formal void newModuleProposal(Integer offset, String prefix, Integer len, 
        String versioned, ModuleDetails mod, Boolean withBody,
        ModuleVersionDetails version, String name, Node node, CompletionContext cpc);
    
    shared formal void newModuleDescriptorProposal(CompletionContext ctx, Integer offset, String prefix, String desc, String text,
        Integer selectionStart, Integer selectionEnd); 
    
    shared formal void newJDKModuleProposal(CompletionContext ctx, Integer offset, String prefix, Integer len, 
        String versioned, String name);

    shared formal void newFunctionCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, Unit unit, CompletionContext cmp);

    shared formal void newControlStructureCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, CompletionContext cpc, Node? node = null);

    shared formal void newTypeProposal(ProposalsHolder proposals, Integer offset, Type? type,
        String text, String desc, Tree.CompilationUnit rootNode);

    shared formal void newAnonFunctionProposal(CompletionContext ctx, Integer offset, Type? requiredType,
        Unit unit, String text, String header, Boolean isVoid,
        Integer selectionStart, Integer selectionLength);
    
    shared formal ProposalsHolder createProposalsHolder();
}