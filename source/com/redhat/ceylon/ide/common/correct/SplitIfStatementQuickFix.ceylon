import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}

shared interface SplitIfStatementQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
 
    shared void addSplitIfStatementProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.IfStatement ifSt = statement) {
            Tree.ElseClause? elseClause = ifSt.elseClause;
            if (!exists elseClause) {
                if (exists cl = ifSt.ifClause.conditionList) {
                    value conditions = cl.conditions;
                    value size = conditions.size();
                    if (size >= 2, 
                        exists c1 = conditions.get(size - 2),
                        exists c2 = conditions.get(size - 1)) {
                        
                        value change = newTextChange("Split If Statement", file);
                        value doc = getDocumentForChange(change);
                        initMultiEditChange(change);
                        String ws;
                        String indent;
                        
                        if (ifSt.token.line == ifSt.endToken.line) {
                            ws = " ";
                            indent = "";
                        } else {
                            ws = indents.getDefaultLineDelimiter(doc)
                                    + indents.getIndent(ifSt, doc);
                            indent = indents.defaultIndent;
                        }
                        
                        value start = c1.endIndex.intValue();
                        value stop = c2.startIndex.intValue();
                        addEditToChange(change, newReplaceEdit(start, stop - start,
                             ") {" + ws + indent + "if ("));
                        value end = ifSt.endIndex.intValue();
                        addEditToChange(change, newInsertEdit(end, ws + "}"));
                        incrementIndent(doc, ifSt, cl, change, indent);
                        
                        newProposal(data, "Split 'if' statement at condition", change);
                    }
                }
            } else if (exists block = elseClause.block,
                       block.token.type == CeylonLexer.\iIF_CLAUSE) {
                value statements = block.statements;

                if (statements.size() == 1) {
                    value st = statements.get(0);
                    if (is Tree.IfStatement st) {
                        value inner = st;
                        value icl = inner.ifClause.conditionList;
                        value change = newTextChange("Split If Statement", file);
                        value doc = getDocumentForChange(change);
                        initMultiEditChange(change);
                        value ws = indents.getDefaultLineDelimiter(doc)
                                + indents.getIndent(ifSt, doc);
                        value indent = indents.defaultIndent;
                        value start = block.startIndex.intValue();
                        addEditToChange(change, newInsertEdit(start, "{" + ws + indent));
                        value end = ifSt.endIndex.intValue();
                        addEditToChange(change, newInsertEdit(end, ws + "}"));
                        incrementIndent(doc, ifSt, icl, change, indent);
                        
                        newProposal(data, "Split 'if' statement at 'else'", change);
                    }
                }
            }
        }
    }
    
    void incrementIndent(IDocument doc, Tree.IfStatement ifSt, Tree.ConditionList cl,
        TextChange change, String indent) {
        
        if (!indent.empty) {
            variable value line = getLineOfOffset(doc, cl.endIndex.intValue() - 1) + 1;
            while (line <= getLineOfOffset(doc, ifSt.endIndex.intValue() - 1)) {
                addEditToChange(change, newInsertEdit(getLineStartOffset(doc, line), indent));
                line++;
            }
        }
    }
}
