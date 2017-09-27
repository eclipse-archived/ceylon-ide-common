import org.eclipse.ceylon.cmr.api {
    ModuleSearchResult {
        ModuleDetails
    },
    ModuleVersionDetails
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import org.eclipse.ceylon.ide.common.completion {
    CompletionContext,
    ProposalsHolder,
    ProposalKind,
    generic
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Scope,
    Reference,
    Unit,
    Type,
    Package,
    DeclarationWithProximity
}

import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    OccurrenceLocation
}

shared interface CompletionServices {
    
    shared formal void addNestedProposal(
        "The holder in which the proposal should be added"
        ProposalsHolder proposals,
        "An icon to be shown in the proposal"
        Icons|Declaration icon,
        "A user-friendly text to be shown in the proposal"
        String description,
        "The region to be replaced with [[text]]"
        DefaultRegion region,
        "The text to be inserted in the editor"
        String text = description
    );

    shared formal void addProposal(
        "The context in which the proposal should be added"
        CompletionContext ctx,
        "The offset where completion was called"
        Integer offset,
        "A text prefix"
        String prefix,
        "An icon to be shown in the proposal"
        Icons|Declaration icon,
        "A user-friendly text to be shown in the proposal"
        String description,
        "The text to be inserted in the editor"
        String text = description,
        ProposalKind kind = generic,
        "An additional change to apply after the text is inserted"
        TextChange? additionalChange = null,
        "A region to be selected after the proposal is applied"
        DefaultRegion? selection = null
    );
    
    shared default void newInvocationCompletion(CompletionContext ctx, Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference()? pr, Scope scope,
        Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation, 
        Boolean inheritance, Boolean qualified, Declaration? qualifyingDec)
            => addProposal(ctx, offset, prefix, dec, desc, text, generic, null, null);
    
    shared formal void newParameterInfo(CompletionContext ctx, Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, Boolean namedInvocation);
    
    shared formal void newParametersCompletionProposal(CompletionContext ctx, Integer offset,
        String prefix, String desc, String text, List<Type> argTypes, Node node, Unit unit);
    
    shared formal void newRefinementCompletionProposal(Integer offset, 
        String prefix, Reference? pr, String desc, String text, CompletionContext cmp,
        Declaration dec, Scope scope, Boolean fullType, Boolean explicitReturnType);

    shared formal void newPackageDescriptorProposal(CompletionContext ctx, 
        Integer offset, String prefix, String desc, String text);
    
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

    shared formal ProposalsHolder createProposalsHolder();

    shared default Boolean customizeInvocationProposals(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity? dwp, Declaration dec, Reference() reference, Scope scope,
        OccurrenceLocation? ol, String? typeArgs, Boolean isMember) => false;

    shared default Boolean customizeReferenceProposals(Tree.CompilationUnit cu,
        Integer offset, String prefix, CompletionContext ctx, DeclarationWithProximity dwp,
        Reference()? reference, Scope scope, OccurrenceLocation? ol, Boolean isMember) => false;
}
