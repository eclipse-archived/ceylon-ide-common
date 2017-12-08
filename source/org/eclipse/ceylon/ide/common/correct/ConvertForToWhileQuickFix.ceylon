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

shared object convertForToWhileQuickFix {
 
    shared void addConvertForToWhileProposal(QuickFixData data,
        Tree.Statement? statement) {
     
        if (is Tree.ForStatement forSt = statement, 
            is Tree.ValueIterator fi = forSt.forClause?.forIterator,
            exists e = fi.specifierExpression?.expression) {
            
            value doc = data.document;
            value change = platformServices.document.createTextChange { 
                name = "Convert For to While";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            change.addEdit(
                InsertEdit {
                    start = forSt.startIndex.intValue();
                    text = "value it = "
                        + doc.getText(e.startIndex.intValue(), e.distance.intValue())
                        + ".iterator();" 
                        + doc.defaultLineDelimiter
                        + doc.getIndent(forSt);
                });
            change.addEdit(
                ReplaceEdit {
                    start = forSt.startIndex.intValue();
                    length = 3;
                    text = "while";
                });
            change.addEdit(
                ReplaceEdit {
                    start = fi.startIndex.intValue()+1;
                    length = fi.distance.intValue()-2;
                    text = "!is Finished " 
                            + fi.variable.identifier.text 
                            + " = it.next()";
                });
               
            data.addQuickFix("Convert 'for' loop to 'while'", change);
        }
    }
    
}
