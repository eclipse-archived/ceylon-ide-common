import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}

shared interface JoinIfStatementsQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {

    shared void addJoinIfStatementsProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.IfStatement statement) {
            if (exists elseClause = statement.elseClause) {
                if (exists block = elseClause.block,
                    block.token.type != CeylonLexer.\iIF_CLAUSE) {
                    
                    value statements = block.statements;
                    if (statements.size() == 1) {
                        value st = statements.get(0);
                        if (is Tree.IfStatement inner = st,
                            exists icl = inner.ifClause.conditionList) {
                            
                            value change = newTextChange("Join If Statements", file);
                            value doc = getDocumentForChange(change);
                            initMultiEditChange(change);
                            value from = block.startIndex.intValue();
                            value to = inner.startIndex.intValue();
                            addEditToChange(change, newDeleteEdit(from, to - from));
                            decrementIndent(doc, inner, icl, change, 
                                indents.getIndent(inner, doc), indents.getIndent(statement, doc));
                            addEditToChange(change, newDeleteEdit(
                                inner.endIndex.intValue(),
                                statement.endIndex.intValue() - inner.endIndex.intValue()));
                            
                            newProposal(data, "Join 'if' statements at 'else'", change);
                        }
                    }
                }
            } else if (exists block = statement.ifClause.block) {
                value statements = block.statements;
                if (statements.size() == 1, 
                    is Tree.IfStatement inner = statements.get(0),
                    exists ocl = statement.ifClause.conditionList,
                    exists icl = inner.ifClause.conditionList,
                    !inner.elseClause exists) {
                    
                    value change = newTextChange("Join If Statements", file);
                    value doc = getDocumentForChange(change);
                    initMultiEditChange(change);
                    addEditToChange(change, newReplaceEdit(
                        ocl.endIndex.intValue() - 1,
                        icl.startIndex.intValue() - ocl.endIndex.intValue() + 2, ", "));
                    
                    decrementIndent(doc, inner, icl, change,
                        indents.getIndent(inner, doc),
                        indents.getIndent(statement, doc));
                    
                    addEditToChange(change, newDeleteEdit(
                        inner.endIndex.intValue(),
                        statement.endIndex.intValue() - inner.endIndex.intValue()));
                    
                    newProposal(data, "Join 'if' statements at condition list", change);
                }
            }
        }
    }
    
    void decrementIndent(IDocument doc, Tree.IfStatement ifSt, Tree.ConditionList cl,
        TextChange change, String indent, String outerIndent) {
        
        value defaultIndent = indents.defaultIndent;
        variable Integer line = getLineOfOffset(doc, cl.stopIndex.intValue()) + 1;
        while (line < getLineOfOffset(doc, ifSt.stopIndex.intValue())) {
            value lineText = getLineContent(doc, line);
            value lineStart = getLineStartOffset(doc, line);
            
            if (lineText.startsWith(indent), indent.startsWith(outerIndent)) {
                addEditToChange(change, newDeleteEdit(lineStart + outerIndent.size,
                    indent.size - outerIndent.size));
            } else if (lineText.startsWith(outerIndent + defaultIndent)) {
                addEditToChange(change, newDeleteEdit(lineStart + outerIndent.size,
                    defaultIndent.size));
            }
            
            line++;
        }
        
        line = getLineOfOffset(doc, ifSt.stopIndex.intValue());
        value lineText = getLineContent(doc, line);
        value lineStart = getLineStartOffset(doc, line);

        if (lineText.startsWith(indent), indent.startsWith(outerIndent)) {
            addEditToChange(change, newReplaceEdit(lineStart, indent.size, outerIndent));
        } else if (lineText.startsWith(outerIndent + defaultIndent)) {
            addEditToChange(change, newReplaceEdit(lineStart, 
                outerIndent.size + defaultIndent.size, outerIndent));
        }
    }
}