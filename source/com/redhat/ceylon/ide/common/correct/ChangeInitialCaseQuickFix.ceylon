import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import java.lang {
    JString=String,
    Character
}
shared interface ChangeInitialCaseQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addChangeIdentifierCaseProposal(Data data, IFile file) {
        variable Tree.Identifier? identifier = null;
        
        if (is Tree.Declaration td = data.node) {
            value id = td.identifier;
            if (!id.text.empty) {
                identifier = id;
            }
        } else if (is Tree.ImportPath ip = data.node) {
            value id = ip.identifiers;

            for (importIdentifier in id) {
                if (exists text = importIdentifier.text,
                    !text.empty,
                    text.first?.uppercase else false) {
                    
                    identifier = importIdentifier;
                    break;
                }
            }
        }
        
        if (exists id = identifier) {
            addProposal(id, data, file);
        }
    }

    void addProposal(Tree.Identifier identifier, Data data, IFile file) {
        value oldIdentifier = JString(identifier.text);
        value first = oldIdentifier.codePointAt(0);
        value newFirst = if (Character.isUpperCase(first)) 
                         then Character.toLowerCase(first) 
                         else Character.toUpperCase(first);
        value newFirstLetter = JString(Character.toChars(newFirst));
        value newIdentifier = newFirstLetter.concat(oldIdentifier.substring(Character.charCount(first)));

        value change = newTextChange("Change initial case of identifier", file);
        addEditToChange(change, newReplaceEdit(identifier.startIndex.intValue(), 1, newFirstLetter.string));
        
        value desc = "Change initial case of identifier to '" + newIdentifier + "'";
        newProposal(data, desc, change);
    }
}
