import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface ConvertSwitchToIfQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
 
    shared void addConvertSwitchToIfProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.SwitchStatement statement) {
            value ss = statement;
            value tfc = newTextChange("Convert Switch To If", file);
            initMultiEditChange(tfc);
            Tree.SwitchClause? sc = ss.switchClause;
            if (!exists sc) {
                return;
            }
            
            value scl = ss.switchCaseList;
            Tree.Switched? switched = sc.switched;
            if (!exists switched) {
                return;
            }
            
            String name;
            
            if (exists e = switched.expression) {
                if (is Tree.BaseMemberExpression t = e.term) {
                    value bme = t;
                    name = bme.declaration.name;
                    addEditToChange(tfc, newDeleteEdit(sc.startIndex.intValue(),
                        scl.startIndex.intValue() - sc.startIndex.intValue()));
                } else {
                    return;
                }
            } else if (exists v = switched.variable) {
                name = v.declarationModel.name;
                addEditToChange(tfc, newReplaceEdit(sc.startIndex.intValue(),
                    v.startIndex.intValue() - sc.startIndex.intValue(), "value "));
                addEditToChange(tfc, newReplaceEdit(sc.endIndex.intValue() - 1, 1, ";"));
            } else {
                return;
            }
            
            variable String kw = "if";
            variable value i = 0;
            
            for (cc in scl.caseClauses) {
                value ci = cc.caseItem;
                if (++i == scl.caseClauses.size(), !scl.elseClause exists) {
                    addEditToChange(tfc, newReplaceEdit(cc.startIndex.intValue(),
                        ci.endIndex.intValue() - cc.startIndex.intValue(), "else"));
                } else {
                    addEditToChange(tfc, newReplaceEdit(cc.startIndex.intValue(), 4, kw));
                    kw = "else if";
                    if (is Tree.IsCase ci) {
                        addEditToChange(tfc, 
                            newInsertEdit(ci.endIndex.intValue() - 1, " " + name));
                    } else if (is Tree.MatchCase ci) {
                        value mc = ci;
                        value el = mc.expressionList;
                        if (el.expressions.size() == 1) {
                            if (exists e0 = el.expressions.get(0), 
                                is Tree.BaseMemberExpression t0 = e0.term) {
                                value bme = t0;
                                value d = bme.declaration;
                                value unit = statement.unit;
                                value start = ci.startIndex.intValue();
                                value len = ci.distance.intValue() - 1;

                                if (unit.nullValueDeclaration.equals(d)) {
                                    addEditToChange(tfc, newReplaceEdit(start, len, "!exists " + name));
                                    continue;
                                } else if (unit.getLanguageModuleDeclaration("true").equals(d)) {
                                    addEditToChange(tfc, newReplaceEdit(start, len, name));
                                    continue;
                                } else if (unit.getLanguageModuleDeclaration("false").equals(d)) {
                                    addEditToChange(tfc, newReplaceEdit(start, len, "!" + name));
                                    continue;
                                }
                            }
                            
                            addEditToChange(tfc, newInsertEdit(ci.startIndex.intValue(), name + " == "));
                        } else {
                            addEditToChange(tfc, newInsertEdit(ci.startIndex.intValue(), name + " in ["));
                            addEditToChange(tfc, newInsertEdit(ci.endIndex.intValue() - 1, "]"));
                        }
                    } else {
                        return;
                    }
                }
            }
            
            newProposal(data, "Convert 'switch' to 'if' chain", tfc,
                DefaultRegion(sc.startIndex.intValue(), 0));
        }
    }
    
    shared void addConvertIfToSwitchProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.IfStatement statement) {
            value ifSt = statement;
            value tfc = newTextChange("Convert If To Switch", file);
            initMultiEditChange(tfc);
            value doc = getDocumentForChange(tfc);
            
            if (exists cl = ifSt.ifClause.conditionList) {
                value conditions = cl.conditions;
                if (conditions.size() == 1) {
                    value condition = conditions.get(0);
                    variable String var;
                    variable String type;
                    if (is Tree.IsCondition condition) {
                        value ic = condition;
                        if (ic.not) {
                            return;
                        }
                        
                        try {
                            value v = ic.variable;
                            value start = v.startIndex.intValue();
                            value len = v.distance.intValue();
                            var = getDocContent(doc, start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                        
                        try {
                            value t = ic.type;
                            value start = t.startIndex.intValue();
                            value len = t.distance.intValue();
                            type = "is " + getDocContent(doc, start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    } else if (is Tree.ExistsCondition condition) {
                        value ec = condition;
                        type = if (ec.not) then "null" else "is Object";
                        try {
                            value v = ec.variable;
                            value start = v.startIndex.intValue();
                            value len = v.distance.intValue();
                            var = getDocContent(doc, start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    } else if (is Tree.BooleanCondition condition) {
                        value ec = condition;
                        type = "true";
                        try {
                            value e = ec.expression;
                            value start = e.startIndex.intValue();
                            value len = e.distance.intValue();
                            var = getDocContent(doc, start, len);
                        } catch (Exception e) {
                            e.printStackTrace();
                            return;
                        }
                    } else {
                        return;
                    }
                    
                    value newline = indents.getDefaultLineDelimiter(doc)
                            + indents.getIndent(ifSt, doc);
                    
                    value _start = ifSt.startIndex.intValue();
                    value len = cl.endIndex.intValue() - _start; 
                    addEditToChange(tfc, newReplaceEdit(_start, len,
                        "switch (" + var + ")" + newline + "case (" + type + ")"));

                    if (exists ec = ifSt.elseClause) {
                        value b = ec.block;
                        if (!b.mainToken exists) {
                            value start = b.startIndex.intValue();
                            value end = b.endIndex.intValue();
                            addEditToChange(tfc, newInsertEdit(start,
                                "{" + newline + indents.defaultIndent));

                            variable value line = getLineOfOffset(doc, start) + 1;
                            while (line <= getLineOfOffset(doc, end)) {
                                addEditToChange(tfc, newInsertEdit(
                                    getLineStartOffset(doc, line), indents.defaultIndent));
                                line++;
                            }
                            
                            addEditToChange(tfc, newInsertEdit(end, newline + "}"));
                        }
                    } else {
                        addEditToChange(tfc, newInsertEdit(ifSt.endIndex.intValue(),
                            newline + "else {}"));
                    }
                    
                    newProposal(data, "Convert 'if' to 'switch'", tfc, 
                        DefaultRegion(ifSt.startIndex.intValue(), 0));
                }
            }
        }
    }
}
