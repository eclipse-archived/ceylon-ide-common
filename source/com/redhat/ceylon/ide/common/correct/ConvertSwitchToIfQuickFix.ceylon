import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    InsertEdit,
    DeleteEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object convertSwitchToIfQuickFix {
 
    shared void addConvertSwitchToIfProposal(QuickFixData data, 
     Tree.Statement? statement) {
        if (is Tree.SwitchStatement statement,
            exists sc = statement.switchClause,
            exists scl = statement.switchCaseList,
            exists switched = sc.switched) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert Switch To If";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            String name;
            if (exists e = switched.expression) {
                if (is Tree.BaseMemberExpression t = e.term,
                    exists d = t.declaration,
                    scl.startIndex exists) {
                    name = d.name;
                    change.addEdit(DeleteEdit {
                        start = sc.startIndex.intValue();
                        length = scl.startIndex.intValue() 
                                - sc.startIndex.intValue();
                    });
                } else {
                    return;
                }
            }
            else if (exists v = switched.variable) {
                name = v.declarationModel.name;
                change.addEdit(ReplaceEdit {
                    start = sc.startIndex.intValue();
                    length = v.startIndex.intValue() 
                            - sc.startIndex.intValue();
                    text = "value ";
                });
                change.addEdit(ReplaceEdit {
                    start = sc.endIndex.intValue() - 1;
                    length = 1;
                    text = ";";
                });
            }
            else {
                return;
            }
            
            variable String kw = "if";
            variable value i = 0;
            for (cc in scl.caseClauses) {
                value ci = cc.caseItem;
                if (++i == scl.caseClauses.size(), 
                    !scl.elseClause exists) {
                    change.addEdit(ReplaceEdit {
                        start = cc.startIndex.intValue();
                        length = ci.endIndex.intValue() 
                                - cc.startIndex.intValue();
                        text = "else";
                    });
                }
                else {
                    change.addEdit(ReplaceEdit {
                        start = cc.startIndex.intValue();
                        length = 4;
                        text = kw;
                    });
                    kw = "else if";
                    switch (ci)
                    case (is Tree.IsCase) {
                        change.addEdit(InsertEdit {
                            start = ci.endIndex.intValue() - 1;
                            text = " " + name;
                        });
                    }
                    case (is Tree.MatchCase) {
                        value el = ci.expressionList;
                        if (el.expressions.size() == 1) {
                            if (exists e0 = el.expressions.get(0), 
                                is Tree.BaseMemberExpression t0 = e0.term) {
                                value bme = t0;
                                value d = bme.declaration;
                                value unit = statement.unit;
                                value start = ci.startIndex.intValue();
                                value len = ci.distance.intValue() - 1;

                                if (d==unit.nullValueDeclaration) {
                                    change.addEdit(ReplaceEdit {
                                        start = start;
                                        length = len;
                                        text = "!exists " + name;
                                    });
                                    continue;
                                }
                                else if (d==unit.trueValueDeclaration) {
                                    change.addEdit(ReplaceEdit {
                                        start = start;
                                        length = len;
                                        text = name;
                                    });
                                    continue;
                                }
                                else if (d==unit.falseValueDeclaration) {
                                    change.addEdit(ReplaceEdit {
                                        start = start;
                                        length = len;
                                        text = "!" + name;
                                    });
                                    continue;
                                }
                            }
                            
                            change.addEdit(InsertEdit {
                                start = ci.startIndex.intValue();
                                text = name + " == ";
                            });
                        }
                        else {
                            change.addEdit(InsertEdit {
                                start = ci.startIndex.intValue();
                                text = name + " in [";
                            });
                            change.addEdit(InsertEdit {
                                start = ci.endIndex.intValue() - 1;
                                text = "]";
                            });
                        }
                    }
                    else {
                        return;
                    }
                }
            }
            
            data.addQuickFix {
                description = "Convert 'switch' to 'if' chain";
                change = change;
                selection = DefaultRegion(sc.startIndex.intValue());
            };
        }
    }
    
    shared void addConvertIfToSwitchProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.IfStatement statement) {
            value ifSt = statement;
            value change
                    = platformServices.document.createTextChange {
                name = "Convert If To Switch";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value doc = change.document;
            
            value ifClause = ifSt.ifClause;
            Tree.Block? ib = ifClause.block;
            if (!exists ib) {
                return;
            }
            if (exists cl = ifClause.conditionList) {
                value conditions = cl.conditions;
                if (conditions.size() == 1) {
                    value condition = conditions.get(0);
                    String var;
                    String type;
                    switch (condition)
                    case (is Tree.IsCondition) {
                        if (condition.not) {
                            return;
                        }
                        
                        try {
                            value v = condition.variable;
                            value start = v.startIndex.intValue();
                            value len = v.distance.intValue();
                            var = doc.getText(start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                        
                        try {
                            value t = condition.type;
                            value start = t.startIndex.intValue();
                            value len = t.distance.intValue();
                            type = "is " + doc.getText(start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    }
                    case (is Tree.ExistsCondition) {
                        type = if (condition.not) then "null" else "is Object";
                        try {
                            if (exists v = condition.variable) {
                                value start = v.startIndex.intValue();
                                value len = v.distance.intValue();
                                var = doc.getText(start, len);
                            } else {
                                return;
                            }
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    }
                    case (is Tree.BooleanCondition) {
                        type = "true";
                        try {
                            value e = condition.expression;
                            value start = e.startIndex.intValue();
                            value len = e.distance.intValue();
                            var = doc.getText(start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    } else {
                        return;
                    }
                    
                    value newline 
                            = doc.defaultLineDelimiter
                            + doc.getIndent(ifSt);
                    
                    value _start = ifSt.startIndex.intValue();
                    value len = cl.endIndex.intValue() - _start; 
                    change.addEdit(ReplaceEdit {
                        start = _start;
                        length = len;
                        text = "switch (``var``)``newline``case (``type``)";
                    });

                    if (exists elseClause = ifSt.elseClause) {
                        Tree.Block? eb = elseClause.block;
                        if (!exists eb) {
                            return;
                        }
                        if (!eb.mainToken exists) {
                            value start = eb.startIndex.intValue();
                            value end = eb.endIndex.intValue();
                            change.addEdit(InsertEdit {
                                start = start;
                                text = "{" + newline + platformServices.document.defaultIndent;
                            });

                            variable value line = doc.getLineOfOffset(start) + 1;
                            while (line <= doc.getLineOfOffset(end)) {
                                change.addEdit(InsertEdit {
                                    start = doc.getLineStartOffset(line);
                                    text = platformServices.document.defaultIndent;
                                });
                                line++;
                            }
                            
                            change.addEdit(InsertEdit {
                                start = end;
                                text = newline + "}";
                            });
                        }
                    } else {
                        change.addEdit(InsertEdit {
                            start = ifSt.endIndex.intValue();
                            text = newline + "else {}";
                        });
                    }
                    
                    data.addQuickFix {
                        description = "Convert 'if' to 'switch'";
                        change = change;
                        selection = DefaultRegion(ifSt.startIndex.intValue());
                    };
                }
            }
        }
    }
}
