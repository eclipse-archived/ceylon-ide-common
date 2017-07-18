import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

import java.lang {
    overloaded
}
import java.util {
    Collections
}


shared object switchQuickFix {

    shared void addElseProposal(QuickFixData data) {
        if (is Tree.SwitchClause node = data.node) {
            object extends Visitor() {

                overloaded
                shared actual void visit(Tree.SwitchStatement that) {
                    if (that.switchClause==node) {
                        value offset = that.endIndex.intValue();
                        value change 
                                = platformServices.document.createTextChange {
                            name = "Add Else";
                            input = data.phasedUnit;
                        };
                        value doc = change.document;
                        value text 
                                = doc.defaultLineDelimiter 
                                + doc.getIndent(node) 
                                + "else {}";
                        change.addEdit(InsertEdit {
                            start = offset;
                            text = text;
                        });
                        
                        data.addQuickFix {
                            description = "Add 'else' clause";
                            change = change;
                            selection = DefaultRegion {
                                start = offset + text.size - 1;
                            };
                        };
                    }
                }

                overloaded
                shared actual void visit(Tree.SwitchExpression that) {
                    if (that.switchClause==node) {
                        value offset = that.endIndex.intValue();
                        value change 
                                = platformServices.document.createTextChange {
                            name = "Add Else";
                            input = data.phasedUnit;
                        };
                        change.addEdit(InsertEdit {
                            start = offset;
                            text = " else nothing";
                        });
                        
                        data.addQuickFix {
                            description = "Add 'else' clause";
                            change = change;
                            selection = DefaultRegion {
                                start = offset + 6;
                                length = 7;
                            };
                        };
                    }
                }
            }.visit(data.rootNode);
        }
    }

    function missingType(Tree.SwitchClause sc, Tree.SwitchCaseList scl) {
        variable value type = sc.switched.expression.typeModel;
        for (cc in scl.caseClauses) {
            switch (item = cc.caseItem) 
            case (is Tree.IsCase) {
                if (exists tn = item.type,
                    exists t = tn.typeModel, 
                    !ModelUtil.isTypeUnknown(t)) {
                    type = type.minus(t);
                }
            }
            case (is Tree.MatchCase) {
                for (Tree.Expression? ex 
                        in item.expressionList.expressions) {
                    if (exists ex, 
                        exists t = ex.typeModel,
                        !ModelUtil.isTypeUnknown(t)) {
                        type = type.minus(t);
                    }
                }
            }
            else {}
        }
        return type;
    }
    
    shared void addCasesProposal(QuickFixData data) {
        if (is Tree.SwitchClause node = data.node, 
            exists e = node.switched.expression, 
            !ModelUtil.isTypeUnknown(e.typeModel)) {
            object extends Visitor() {

                overloaded
                shared actual void visit(Tree.SwitchStatement that) {
                    if (that.switchClause==node) {
                        value type = missingType(node, that.switchCaseList);
                        
                        value change 
                                = platformServices.document.createTextChange {
                            name = "Add Cases";
                            input = data.phasedUnit;
                        };
                        value doc = change.document;
                        
                        value text = StringBuilder();
                        value list = type.caseTypes 
                            else Collections.singletonList(type);
                        value unit = data.rootNode.unit;
                        for (pt in list) {
                            text.append(doc.defaultLineDelimiter)
                                .append(doc.getIndent(data.node))
                                .append("case (")
                                .append(pt.declaration.anonymous then "" else "is ")
                                .append(pt.asString(unit))
                                .append(") {}");
                        }
                        
                        value offset = that.endIndex.intValue();
                        change.addEdit(InsertEdit {
                            start = offset;
                            text = text.string;
                        });
                        
                        data.addQuickFix {
                            description = "Add missing 'case' clauses";
                            change = change;
                            selection = DefaultRegion {
                                start = offset + text.size - 1;
                            };
                        };
                    }
                }

                overloaded
                shared actual void visit(Tree.SwitchExpression that) {
                    if (that.switchClause==node) {
                        value type = missingType(node, that.switchCaseList);
                        
                        value change 
                                = platformServices.document.createTextChange {
                            name = "Add Cases";
                            input = data.phasedUnit;
                        };
                        
                        value text = StringBuilder();
                        value list = type.caseTypes 
                        else Collections.singletonList(type);
                        value unit = data.rootNode.unit;
                        for (pt in list) {
                            text.append(" case (")
                                .append(pt.declaration.anonymous then "" else "is ")
                                .append(pt.asString(unit))
                                .append(") nothing");
                        }
                        
                        value offset = that.endIndex.intValue();
                        change.addEdit(InsertEdit {
                            start = offset;
                            text = text.string;
                        });
                        
                        data.addQuickFix {
                            description = "Add missing 'case' clauses";
                            change = change;
                            selection = DefaultRegion {
                                start = offset + text.string.indexOf("nothing");
                                length = 7;
                            };
                        };
                    }
                }
            }.visit(data.rootNode);
        }
    }
}
