/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
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
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.model.typechecker.model {
    ModelUtil
}

shared object changeToQuickFix {
    
    shared void changeToFunction(QuickFixData data) {
        if (is Tree.AnyMethod method 
                = nodes.findDeclarationWithBody {
                    cu = data.rootNode;
                    node = data.node;
                },
            is Tree.Return ret = data.node,
            is Tree.VoidModifier type = method.type) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Change to Function";
                input = data.phasedUnit;
            };
            value unit = data.rootNode.unit;
            value rt = ret.expression.typeModel;
            change.addEdit(ReplaceEdit {
                start = type.startIndex.intValue();
                length = type.distance.intValue();
                text = ModelUtil.isTypeUnknown(rt) 
                    then "function" 
                    else rt.asSourceCodeString(unit);
            });
            
            data.addQuickFix {
                description = "Make function non-'void'";
                change = change;
                affectsOtherUnits = true;
            };
        }
    }

    shared void changeToVoid(QuickFixData data) {
        if (is Tree.AnyMethod dec 
                = nodes.findDeclarationWithBody {
                    cu = data.rootNode;
                    node = data.node;
                }) {
            value type = dec.type;
            if (!(type is Tree.VoidModifier)) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Change to Void";
                    input = data.phasedUnit;
                };
                change.addEdit(ReplaceEdit {
                    start = type.startIndex.intValue();
                    length = type.distance.intValue();
                    text = "void";
                });
                
                data.addQuickFix {
                    description = "Make function 'void'";
                    change = change;
                    affectsOtherUnits = true;
                };
            }
        }
    }
}
