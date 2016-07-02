import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit,
    ReplaceEdit,
    CommonDocument,
    TextChange
}

shared object joinIfStatementsQuickFix {

    shared void addJoinIfStatementsProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.IfStatement statement) {
            if (exists elseClause = statement.elseClause) {
                if (exists block = elseClause.block,
                    block.token.type != CeylonLexer.ifClause, 
                    is Tree.IfStatement inner = block.statements[0],
                    exists icl = inner.ifClause.conditionList) {
                    
                    value doc = data.document;
                    value change 
                            = platformServices.document.createTextChange {
                        name = "Join If Statements";
                        input = data.phasedUnit;
                    };
                    change.initMultiEdit();
                    
                    value from = block.startIndex.intValue();
                    value to = inner.startIndex.intValue();
                    change.addEdit(DeleteEdit {
                        start = from;
                        length = to - from;
                    });
                    decrementIndent {
                        doc = doc;
                        ifSt = inner;
                        cl = icl;
                        change = change;
                        indent = doc.getIndent(inner);
                        outerIndent = doc.getIndent(statement);
                    };
                    change.addEdit(DeleteEdit {
                        start = inner.endIndex.intValue();
                        length = statement.endIndex.intValue() 
                                - inner.endIndex.intValue();
                    });
                    
                    data.addQuickFix("Join 'if' statements at 'else'", change);
                }
            }
            else if (exists block = statement.ifClause.block) {
                if (is Tree.IfStatement inner = block.statements[0],
                    exists ocl = statement.ifClause.conditionList,
                    exists icl = inner.ifClause.conditionList,
                    !inner.elseClause exists) {
                    
                    value doc = data.document;
                    value change 
                            = platformServices.document.createTextChange {
                        name = "Join If Statements";
                        input = data.phasedUnit;
                    };
                    change.initMultiEdit();
                    
                    change.addEdit(ReplaceEdit {
                        start = ocl.endIndex.intValue() - 1;
                        length = icl.startIndex.intValue() 
                                - ocl.endIndex.intValue() + 2;
                        text = ", ";
                    });
                    
                    decrementIndent {
                        doc = doc;
                        ifSt = inner;
                        cl = icl;
                        change = change;
                        indent = doc.getIndent(inner);
                        outerIndent = doc.getIndent(statement);
                    };
                    
                    change.addEdit(DeleteEdit {
                        start = inner.endIndex.intValue();
                        length = statement.endIndex.intValue() 
                                - inner.endIndex.intValue();
                    });
                    
                    data.addQuickFix("Join 'if' statements at condition list", change);
                }
            }
        }
    }
    
    void decrementIndent(CommonDocument doc, Tree.IfStatement ifSt, Tree.ConditionList cl,
        TextChange change, String indent, String outerIndent) {
        
        value defaultIndent = platformServices.document.defaultIndent;
        variable Integer line = doc.getLineOfOffset(cl.stopIndex.intValue()) + 1;
        while (line < doc.getLineOfOffset(ifSt.stopIndex.intValue())) {
            value lineText = doc.getLineContent(line);
            value lineStart = doc.getLineStartOffset(line);
            
            if (lineText.startsWith(indent), 
                indent.startsWith(outerIndent)) {
                change.addEdit(DeleteEdit {
                    start = lineStart + outerIndent.size;
                    length = indent.size - outerIndent.size;
                });
            } 
            else if (lineText.startsWith(outerIndent + defaultIndent)) {
                change.addEdit(DeleteEdit {
                    start = lineStart + outerIndent.size;
                    length = defaultIndent.size;
                });
            }
            
            line++;
        }
        
        line = doc.getLineOfOffset(ifSt.stopIndex.intValue());
        value lineText = doc.getLineContent(line);
        value lineStart = doc.getLineStartOffset(line);

        if (lineText.startsWith(indent), 
            indent.startsWith(outerIndent)) {
            change.addEdit(ReplaceEdit {
                start = lineStart;
                length = indent.size;
                text = outerIndent;
            });
        } 
        else if (lineText.startsWith(outerIndent + defaultIndent)) {
            change.addEdit(ReplaceEdit {
                start = lineStart;
                length = outerIndent.size + defaultIndent.size;
                text = outerIndent;
            });
        }
    }
}