/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    FindReferencesVisitor
}

shared object shadowReferenceQuickFix {
    
    value quickFixDesc => "Shadow reference inside control structure";
    
    shared void addShadowSwitchReferenceProposal(QuickFixData data) {
        if (is Tree.Term node = data.node) {
            value statement = nodes.findStatement(data.rootNode, node);
            
            if (is Tree.SwitchStatement statement) {
                value name = nodes.nameProposals {
                    node = node;
                    rootNode = data.rootNode;
                }[0];
                value change 
                        = platformServices.document.createTextChange {
                    name = "Shadow Reference";
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
//                Integer offset = statement.getStartIndex();
//                change.addEdit(new ReplaceEdit(offset,
//                        node.getStartIndex()-offset,
//                        "value " + name + " = "));
//                IDocument doc = getDocument(change);
//                change.addEdit(new InsertEdit(node.getEndIndex(),
//                        ";" +
//                        getDefaultLineDelimiter(doc) +
//                        getIndent(statement, doc) +
//                        "switch (" + name));
                value ss = statement;
                value loc = node.startIndex.intValue();
                change.addEdit(InsertEdit(loc, name + " = "));
                
                if (is Tree.BaseMemberExpression bme = node,
                    exists d = bme.declaration) {

                    value frv = FindReferencesVisitor(d);
                    frv.visit(ss.switchCaseList);
                    for (n in frv.referenceNodes) {
                        if (exists identifyingNode 
                                = nodes.getIdentifyingNode(n)) {
                            value start = identifyingNode.startIndex.intValue();
                            if (start != loc) {
                                value len = identifyingNode.text.size;
                                change.addEdit(ReplaceEdit(start, len, name));
                            }
                        }
                    }
                }
                
                data.addQuickFix {
                    description = quickFixDesc;
                    change = change;
                    selection = DefaultRegion(loc, name.size);
                };
            }
        }
    }

    shared void addShadowReferenceProposal(QuickFixData data) {
        switch (node = data.node)
        case (is Tree.Variable) {
            value offset = node.identifier.startIndex.intValue();
            value term = node.specifierExpression.expression.term;
            value name = nodes.nameProposals {
                node = term;
                rootNode = data.rootNode;
            }[0];
            value change 
                    = platformServices.document.createTextChange {
                name = "Shadow Reference";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            change.addEdit(InsertEdit(offset, name + " = "));
            value statement 
                    = nodes.findStatement {
                cu = data.rootNode;
                node = node;
            };
            value dec = node.declarationModel;
            value frv = FindReferencesVisitor(dec);
            frv.visit(statement);
            for (n in frv.referenceNodes) {
                value identifyingNode = nodes.getIdentifyingNode(n);
                
                if (exists identifyingNode) {
                    value start = identifyingNode.startIndex.intValue();
                    if (start != offset) {
                        value len = identifyingNode.text.size;
                        change.addEdit(ReplaceEdit(start, len, name));
                    }
                }
            }
            
            data.addQuickFix {
                description = quickFixDesc;
                change = change;
                selection = DefaultRegion(offset, name.size);
            };
        }
        case (is Tree.Term) {
            value name = nodes.nameProposals(node)[0];
            value change 
                    = platformServices.document.createTextChange {
                name = "Shadow Reference";
                input = data.phasedUnit;
            };
            value offset = node.startIndex.intValue();
            
            change.addEdit(InsertEdit(offset, name + " = "));
            data.addQuickFix {
                description = quickFixDesc;
                change = change;
                selection = DefaultRegion(offset, name.size);
            };
        }
        else {}
    }
}
