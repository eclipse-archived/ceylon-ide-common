import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface AddPunctuationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, Integer offset, Integer length,
        String desc, TextChange change);
    
    shared void addEmptyParameterListProposal(Data data, IFile file) {
        assert (is Tree.Declaration decNode = data.node);
        value n = correctionUtil.getBeforeParenthesisNode(decNode);
        
        value dec = decNode.declarationModel;
        value change = newTextChange("Add Empty Parameter List", file);
        value offset = n.endIndex.intValue();
        addEditToChange(change, newInsertEdit(offset, "()"));
        
        newProposal(data, offset + 1, 0, "Add '()' empty parameter list to " 
            + correctionUtil.getDescription(dec), change);
    }

    shared void addImportWildcardProposal(Data data, IFile file) {
        if (is Tree.ImportMemberOrTypeList node = data.node) {
            value imtl = node;
            value change = newTextChange("Add Import Wildcard", file);
            value offset = imtl.startIndex.intValue();
            value length = imtl.distance.intValue();
            addEditToChange(change, newReplaceEdit(offset, length, "{ ... }"));
            
            newProposal(data, offset + 2, 3, "Add '...' import wildcard", change);
        }
    }

}