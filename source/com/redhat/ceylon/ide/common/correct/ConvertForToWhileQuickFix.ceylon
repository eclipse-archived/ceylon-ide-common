import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface ConvertForToWhileQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
 
    shared void addConvertForToWhileProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.ForStatement forSt = statement, 
            is Tree.ValueIterator fi = forSt.forClause?.forIterator,
            exists e = fi.specifierExpression?.expression) {
            
            value change = newTextChange("Convert For to While", file);
            value doc = getDocumentForChange(change);
            initMultiEditChange(change);
            addEditToChange(change, 
                newInsertEdit {
                    position = forSt.startIndex.intValue();
                    text = "value it = " + this.getDocContent {
                        doc = doc;
                        start = e.startIndex.intValue();
                        length = e.distance.intValue();
                    } 
                        + ".iterator();" 
                        + indents.getDefaultLineDelimiter(doc)
                        + indents.getIndent(forSt, doc);
                });
            addEditToChange(change, 
                newReplaceEdit {
                    start = forSt.startIndex.intValue();
                    length = 3;
                    text = "while";
                });
            addEditToChange(change, 
                newReplaceEdit {
                    start = fi.startIndex.intValue()+1;
                    length = fi.distance.intValue()-2;
                    text = "!is Finished " 
                            + fi.variable.identifier.text 
                            + " = it.next()";
                });
            newProposal(data, "Convert 'for' loop to 'while'", change);
        }
    }
    
}
