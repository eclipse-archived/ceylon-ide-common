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
    ReplaceEdit
}
shared object changeInitialCaseQuickFix {
    
    shared void addChangeIdentifierCaseProposal(QuickFixData data) {
        switch (node = data.node)
        case (is Tree.Declaration) {
            value id = node.identifier;
            if (!id.text.empty) {
                addProposal(id, data);
            }
        }
        case (is Tree.ImportPath) {
            for (importIdentifier in node.identifiers) {
                if (exists text = importIdentifier.text,
                    !text.empty,
                    text.first?.uppercase else false) {
                    addProposal(importIdentifier, data);
                    break;
                }
            }
        }
        else {}
    }

    void addProposal(Tree.Identifier identifier, QuickFixData data) {
        value oldIdentifier = identifier.text;
        if (exists first = oldIdentifier.first) {
            value newFirstLetter
                    = first.uppercase then first.lowercased 
                                      else first.uppercased;
            value newIdentifier
                    = newFirstLetter.string
                    + oldIdentifier.spanFrom(1);
            
            value change = platformServices.document.createTextChange {
                name = "Change Initial Case of Identifier";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                start = identifier.startIndex.intValue();
                length = 1;
                text = newFirstLetter.string;
            });
            data.addQuickFix {
                description = "Change initial case of identifier to '``newIdentifier``'";
                change = change;
            };
        }
    }
}
