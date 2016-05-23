import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

import java.util {
    Collections
}


shared object switchQuickFix {
    
    shared void addElseProposal(QuickFixData data) {
        if (is Tree.SwitchClause node = data.node, 
            is Tree.SwitchStatement st 
                    = nodes.findStatement {
                        cu = data.rootNode;
                        node = node;
                    }) {
            value offset = st.endIndex.intValue();
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
        //TODO: else handle switch *expressions* 
    }

    shared void addCasesProposal(QuickFixData data) {
        //TODO: handle switch expressions!
        if (is Tree.SwitchClause sc = data.node, 
            is Tree.SwitchStatement ss 
                    = nodes.findStatement {
                        cu = data.rootNode;
                        node = sc;
                    }, 
            exists e = sc.switched.expression, 
            exists _type = e.typeModel) {
            
            value scl = ss.switchCaseList;
            variable value type = _type;
            
            for (cc in scl.caseClauses) {
                value item = cc.caseItem;
                
                if (is Tree.IsCase ic = item) {
                    if (exists tn = ic.type) {
                        value t = tn.typeModel;
                        
                        if (!ModelUtil.isTypeUnknown(t)) {
                            type = type.minus(t);
                        }
                    }
                } else if (is Tree.MatchCase item) {
                    value ic = item;
                    value il = ic.expressionList;
                    for (Tree.Expression? ex in il.expressions) {
                        if (exists ex, 
                            exists t = ex.typeModel,
                            !ModelUtil.isTypeUnknown(t)) {
                            
                            type = type.minus(t);
                        }
                    }
                }
            }
            
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
            
            value offset = ss.endIndex.intValue();
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
}
