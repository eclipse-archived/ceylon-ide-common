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
    Visitor,
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.model.typechecker.util {
    TypePrinter
}

shared object expandTypeQuickFix {

    shared void addExpandTypeProposal(QuickFixData data, Tree.Statement? node,
        Integer selectionStart, Integer selectionStop) {
        
        if (!exists node) {
            return;
        }
        variable Tree.Type? result = null;
        
        node.visit(object extends Visitor() {
            shared actual void visit(Tree.Type that) {
                super.visit(that);
                value start = that.startIndex?.intValue();
                value stop = that.endIndex?.intValue();
                if (exists start, exists stop,
                    selectionStart <= start,
                    selectionStop >= stop) {
                    
                    result = that;
                }
            }
        });
        
        if (exists res = result) {
            value start = res.startIndex.intValue();
            value len = res.distance.intValue();
            value change 
                    = platformServices.document.createTextChange {
                name = "Expand Type";
                input = data.phasedUnit;
            };
            value text = change.document.getText(start, len);
            
            value unabbreviated 
                    = TypePrinter(false)
                        .print(res.typeModel, node.unit);
            
            if (unabbreviated != text) {
                change.addEdit(ReplaceEdit {
                    start = start;
                    length = len;
                    text = unabbreviated;
                });
                
                data.addQuickFix {
                    description = "Expand type abbreviation";
                    change = change;
                    selection = DefaultRegion {
                        start = start;
                        length = unabbreviated.size;
                    };
                };
            }
        }
    }
}