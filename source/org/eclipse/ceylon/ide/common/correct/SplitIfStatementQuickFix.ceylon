/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    ReplaceEdit,
    CommonDocument,
    TextChange
}

shared object splitIfStatementQuickFix {
 
    shared void addSplitIfStatementProposal(QuickFixData data, 
     Tree.Statement? statement) {
        if (is Tree.IfStatement ifSt = statement) {
            Tree.ElseClause? elseClause = ifSt.elseClause;
            if (!exists elseClause) {
                if (exists cl = ifSt.ifClause.conditionList) {
                    value conditions = cl.conditions;
                    value size = conditions.size();
                    if (exists c1 = conditions[size - 2],
                        exists c2 = conditions[size - 1]) {
                        
                        value doc = data.document;
                        value change 
                                = platformServices.document.createTextChange {
                            name = "Split If Statement";
                            input = data.phasedUnit;
                        };
                        change.initMultiEdit();
                        String ws;
                        String indent;
                        
                        if (ifSt.token.line == ifSt.endToken.line) {
                            ws = " ";
                            indent = "";
                        } else {
                            ws = doc.defaultLineDelimiter
                                    + doc.getIndent(ifSt);
                            indent = platformServices.document.defaultIndent;
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
                        incrementIndent {
                            doc = doc;
                            ifSt = ifSt;
                            cl = cl;
                            change = change;
                            indent = indent;
                        };
                        
                        data.addQuickFix {
                            description = "Split 'if' statement at condition";
                            change = change;
                        };
                    }
                }
            } else if (exists block = elseClause.block,
                       block.token.type == CeylonLexer.ifClause) {

                if (is Tree.IfStatement st = block.statements[0],
                    exists value icl = st.ifClause.conditionList) {

                    value doc = data.document;
                    value change
                            = platformServices.document.createTextChange(
                                "Split If Statement", doc);
                    change.initMultiEdit();
                    value ws
                            = doc.defaultLineDelimiter
                            + doc.getIndent(ifSt);
                    value indent = platformServices.document.defaultIndent;
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
                    incrementIndent {
                        doc = doc;
                        ifSt = ifSt;
                        cl = icl;
                        change = change;
                        indent = indent;
                    };

                    data.addQuickFix {
                        description = "Split 'if' statement at 'else'";
                        change = change;
                    };
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
