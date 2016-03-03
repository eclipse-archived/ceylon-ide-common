import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface ConvertToGetterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared void addConvertToGetterProposal(Data data, IFile file, Tree.AttributeDeclaration? decNode) {
        if (exists decNode,
            exists dec = decNode.declarationModel, 
            exists sie = decNode.specifierOrInitializerExpression) {
            
            if (dec.parameter) {
                return;
            }
            
            if (!dec.variable) { //TODO: temp restriction, autocreate setter!
                value change = newTextChange("Convert to Getter", file);
                initMultiEditChange(change);
                value offset = sie.startIndex.intValue();
                value doc = getDocumentForChange(change);
                value char = getDocContent(doc, offset - 1, 1).first else ' ';
                value space = if (char == ' ') then "" else " ";
                
                addEditToChange(change, newReplaceEdit(offset, 1, "=>"));
                // change.addEdit(new ReplaceEdit(offset, 1, space + "{ return" + spaceAfter));
                // change.addEdit(new InsertEdit(decNode.getStopIndex()+1, " }"));

                value desc = "Convert '" + dec.name + "' to getter";
                newProposal(data, desc, change, DefaultRegion(offset + space.size + 2, 0));
            }
        }
    }
}
