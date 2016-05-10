import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import org.antlr.runtime {
    CommonToken
}

shared interface ChangeDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared formal void newProposal(Data data, String keyword, String desc, Integer position, TextChange change);
    
    shared void addChangeDeclarationProposal(Data data, IFile file) {
        assert (is Tree.Declaration decNode = data.node);
        if (exists token = decNode.mainToken) {
            String keyword;
            switch (decNode)
            case (is Tree.AnyClass) {
                keyword = "interface";
            }
            case (is Tree.AnyMethod) {
                if (token.type==CeylonLexer.\iVOID_MODIFIER) {
                    return;
                }
                keyword = "value";
            }
            else {
                return;
            }
            
            assert (is CommonToken token);
            
            value change = newTextChange("Change Declaration", file);
            addEditToChange(change, newReplaceEdit(token.startIndex, token.text.size, keyword));
            
            value desc = "Change declaration to '" + keyword + "'";
            newProposal(data, keyword, desc, token.startIndex, change);
        }
    }
}
