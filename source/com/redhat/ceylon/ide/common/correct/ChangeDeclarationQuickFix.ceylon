import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import org.antlr.runtime {
    CommonToken
}

shared interface ChangeDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {

    shared formal void newProposal(Data data, String keyword, String desc, Integer position, TextChange change);
    
    shared void addChangeDeclarationProposal(Data data, IFile file) {
        assert (is Tree.Declaration decNode = data.node);
        assert (is CommonToken token = decNode.mainToken);
        
        String keyword;
        if (is Tree.AnyClass decNode) {
            keyword = "interface";
        } else if (is Tree.AnyMethod decNode) {
            if (token.text.equals("void")) {
                return;
            }
            
            keyword = "value";
        } else {
            return;
        }
        
        value change = newTextChange("Change Declaration", file);
        addEditToChange(change, newReplaceEdit(token.startIndex, token.text.size, keyword));
        
        value desc = "Change declaration to '" + keyword + "'";
        newProposal(data, keyword, desc, token.startIndex, change);
    }
}
