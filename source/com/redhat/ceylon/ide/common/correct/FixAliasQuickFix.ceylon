shared interface FixAliasQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, Integer offset, TextChange change);
    
    shared void addFixAliasProposal(Data data, IFile file) {
        value offset = data.problemOffset;
        value change = newTextChange("Fix Alias Syntax", file);
        initMultiEditChange(change);
        addEditToChange(change, newReplaceEdit(offset, 1, "=>"));
        
        newProposal(data, "Change = to =>", offset + 2, change);
    }
}
