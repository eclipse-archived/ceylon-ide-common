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
    ReplaceEdit,
    platformUtils,
    Status
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object addPunctuationQuickFix {
    
    shared void addEmptyParameterListProposal(QuickFixData data) {
        if (is Tree.Declaration decNode = data.node) {

            value dec = decNode.declarationModel;
            value change
                    = platformServices.document.createTextChange {
                name = "Add Empty Parameter List";
                input = data.phasedUnit;
            };
            value offset
                    = correctionUtil.getBeforeParenthesisNode(decNode)
                .endIndex
                .intValue();
            change.addEdit(InsertEdit {
                start = offset;
                text = "()";
            });

            data.addQuickFix {
                description
                        = "Add '()' empty parameter list to "
                        + correctionUtil.getDescription(dec);
                change = change;
                selection = DefaultRegion(offset + 1, 0);
            };
        } else {
            platformUtils.log(Status._WARNING,
                "data.node (``
                data.node.nodeType else "<null>"
                ``) is not a Tree.Declaration");
        }
    }

    shared void addImportWildcardProposal(QuickFixData data) {
        if (is Tree.ImportMemberOrTypeList node = data.node) {
            value imtl = node;
            value change 
                    = platformServices.document.createTextChange {
                name = "Add Import Wildcard";
                input = data.phasedUnit;
            };
            value offset = imtl.startIndex.intValue();
            value length = imtl.distance.intValue();
            change.addEdit(ReplaceEdit {
                start = offset;
                length = length;
                text = "{ ... }";
            });
            
            data.addQuickFix {
                description = "Add '...' import wildcard";
                change = change;
                selection = DefaultRegion(offset + 2, 3);
            };
        }
    }

}