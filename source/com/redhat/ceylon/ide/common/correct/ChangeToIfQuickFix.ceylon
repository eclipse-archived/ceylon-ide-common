import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}

shared interface ChangeToIfQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
 
    shared void addChangeToIfProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.Assertion statement) {
            if (exists conditionList = statement.conditionList) {
                object findBodyVisitor extends Visitor() {
                    shared variable Tree.Body? result = null;
                    
                    shared actual void visit(Tree.Body that) {
                        if (that.statements.contains(statement)) {
                            result = that;
                        } else {
                            super.visit(that);
                        }
                    }
                }
                
                findBodyVisitor.visit(data.rootNode);
                
                if (exists body = findBodyVisitor.result) {
                    value statements = body.statements;
                    value last = statements.get(statements.size() - 1);
                    value isLast = statement == last;
                    value change = newTextChange("Change Assert To If", file);
                    initMultiEditChange(change);
                    value doc = getDocumentForChange(change);
                    value newline = indents.getDefaultLineDelimiter(doc);
                    value indent = indents.getIndent(last, doc);
                    value begin = statement.startIndex.intValue();
                    value end = conditionList.startIndex.intValue();
                    
                    addEditToChange(change, newReplaceEdit(begin, end - begin, "if "));
                    addEditToChange(change, newReplaceEdit(statement.endIndex.intValue() - 1,
                        1, if (isLast) then " {}" else " {"));
                    
                    //TODO: this is wrong, need to look for lines, not statements!
                    variable value i = statements.indexOf(statement) + 1;
                    while (i < statements.size()) {
                        addEditToChange(change, newInsertEdit(
                            statements.get(i).startIndex.intValue(), 
                            indents.defaultIndent)
                        );
                        i++;
                    }
                    
                    if (!isLast) {
                        addEditToChange(change, newInsertEdit(last.endIndex.intValue(),
                            newline + indent + "}"));
                    }
                    
                    value elseBlock = newline + indent + "else {" + newline 
                            + indent + indents.defaultIndent
                            + "assert (false);" + newline + indent + "}";
                    
                    addEditToChange(change, newInsertEdit(last.endIndex.intValue(), elseBlock));
                    
                    newProposal(data, "Change 'assert' to 'if'", change, 
                        DefaultRegion(statement.endIndex.intValue() - 3, 0));   
                }
            }
        }
    }
}
