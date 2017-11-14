/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

import org.antlr.runtime {
    CommonToken
}

shared object changeDeclarationQuickFix {

    shared void addChangeDeclarationProposal(QuickFixData data) {
        if (is Tree.Declaration decNode = data.node,
            is CommonToken token = decNode.mainToken) {

            String keyword;
            switch (decNode)
            case (is Tree.AnyClass) {
                keyword = "interface";
            }
            case (is Tree.AnyMethod) {
                if (token.type==CeylonLexer.voidModifier) {
                    return;
                }
                keyword = "value";
            }
            else {
                return;
            }
                        
            value change 
                    = platformServices.document.createTextChange {
                name = "Change Declaration";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                start = token.startIndex;
                length = token.text.size;
                text = keyword;
            });
            data.addQuickFix {
                description = "Change declaration to '``keyword``'";
                change = change;
                selection = DefaultRegion {
                    start = token.startIndex;
                    length = keyword.size;
                };
            };
        }
    }
}
