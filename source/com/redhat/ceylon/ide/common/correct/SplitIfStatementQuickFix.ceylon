import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    commonIndents,
    InsertEdit,
    ReplaceEdit,
    CommonDocument,
    TextChange
}

shared object splitIfStatementQuickFix {
 
    shared void addSplitIfStatementProposal(AnyQuickFixData data, 
     Tree.Statement? statement) {
        if (is Tree.IfStatement ifSt = statement) {
            Tree.ElseClause? elseClause = ifSt.elseClause;
            if (!exists elseClause) {
                if (exists cl = ifSt.ifClause.conditionList) {
                    value conditions = cl.conditions;
                    value size = conditions.size();
                    if (size >= 2, 
                        exists c1 = conditions.get(size - 2),
                        exists c2 = conditions.get(size - 1)) {
                        
                        value doc = data.doc;
                        value change 
                                = platformServices.createTextChange(
                                    "Split If Statement", doc);
                        change.initMultiEdit();
                        String ws;
                        String indent;
                        
                        if (ifSt.token.line == ifSt.endToken.line) {
                            ws = " ";
                            indent = "";
                        } else {
                            ws = commonIndents.getDefaultLineDelimiter(doc)
                                    + commonIndents.getIndent(ifSt, doc);
                            indent = commonIndents.defaultIndent;
                        }
                        
                        value start = c1.endIndex.intValue();
                        value stop = c2.startIndex.intValue();
                        change.addEdit( 
                            ReplaceEdit {
                                start = start;
                                length = stop - start;
                                text = ") {" + ws + indent + "if (";
                            });
                        change.addEdit( 
                            InsertEdit {
                                start = ifSt.endIndex.intValue();
                                text = ws + "}";
                            });
                        incrementIndent(doc, ifSt, cl, change, indent);
                        
                        data.addQuickFix("Split 'if' statement at condition", change);
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
                        value doc = data.doc;
                        value change 
                                = platformServices.createTextChange(
                                    "Split If Statement", doc);
                        change.initMultiEdit();
                        value ws 
                                = commonIndents.getDefaultLineDelimiter(doc)
                                + commonIndents.getIndent(ifSt, doc);
                        value indent = commonIndents.defaultIndent;
                        value start = block.startIndex.intValue();
                        change.addEdit( 
                            InsertEdit {
                                start = start;
                                text = "{" + ws + indent;
                            });
                        change.addEdit(
                            InsertEdit {
                                start = ifSt.endIndex.intValue();
                                text = ws + "}";
                            });
                        incrementIndent(doc, ifSt, icl, change, indent);
                        
                        data.addQuickFix("Split 'if' statement at 'else'", change);
                    }
                }
            }
        }
    }
    
    void incrementIndent(CommonDocument doc, Tree.IfStatement ifSt, Tree.ConditionList cl,
        TextChange change, String indent) {
        
        if (!indent.empty) {
            variable value line 
                    = doc.getLineOfOffset(cl.endIndex.intValue() - 1) + 1;
            while (line <= doc.getLineOfOffset(ifSt.endIndex.intValue() - 1)) {
                change.addEdit( 
                    InsertEdit {
                        start = doc.getLineStartOffset(line);
                        text = indent;
                    });
                line++;
            }
        }
    }
}
