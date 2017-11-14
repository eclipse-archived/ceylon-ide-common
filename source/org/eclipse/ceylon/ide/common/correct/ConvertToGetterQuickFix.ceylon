/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}

shared object convertToGetterQuickFix {
    
    shared void addConvertToGetterProposal(QuickFixData data, Tree.AttributeDeclaration? decNode) {
        if (exists decNode,
            exists dec = decNode.declarationModel, 
            exists sie = decNode.specifierOrInitializerExpression) {
            
            if (dec.parameter) {
                return;
            }
            
            if (!dec.variable) { //TODO: temp restriction, autocreate setter!
                value change 
                        = platformServices.document.createTextChange {
                    name = "Convert to Getter";
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
                value offset = sie.startIndex.intValue();
                value char = change.document.getText(offset-1, 1).first else ' ';
                value space = char == ' ' then "" else " ";
                
                change.addEdit(ReplaceEdit {
                    start = offset;
                    length = 1;
                    text = "=>";
                });
                // change.addEdit(new ReplaceEdit(offset, 1, space + "{ return" + spaceAfter));
                // change.addEdit(new InsertEdit(decNode.getStopIndex()+1, " }"));

                value desc = "Convert '``dec.name``' to getter";
                data.addQuickFix {
                    description = desc;
                    change = change;
                    selection = DefaultRegion {
                        start = offset + space.size + 2;
                        length = 0;
                    };
                };
            }
        }
    }
}
