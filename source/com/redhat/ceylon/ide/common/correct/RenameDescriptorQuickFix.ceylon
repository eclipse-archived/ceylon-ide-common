import com.redhat.ceylon.ide.common.util {
    escaping
}

shared interface RenameDescriptorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addRenameDescriptorProposal(Data data, IFile file) {
        value pn = escaping.escapePackageName(data.rootNode.unit.\ipackage);
        value change = newTextChange("Rename", file);
        
        addEditToChange(change, newReplaceEdit(data.problemOffset, data.problemLength, pn));
        
        value desc = "Rename to '" + pn + "'";
        
        newProposal(data, desc, change);
    }
}
 