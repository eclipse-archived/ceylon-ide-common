/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.util {
    escaping
}

shared object renameDescriptorQuickFix {
    
    shared void addRenameDescriptorProposal(QuickFixData data) {
        value pack = data.rootNode.unit.\ipackage;
        value pname = escaping.escapePackageName(pack);
        
        value change 
                = platformServices.document.createTextChange {
            name = "Rename";
            input = data.phasedUnit;
        };
        
        change.addEdit(ReplaceEdit {
            start = data.problemOffset;
            length = data.problemLength;
            text = pname;
        });
        
        data.addQuickFix {
            description = "Rename to '``pack.qualifiedNameString``'";
            change = change;
            qualifiedNameIsPath = true;
            affectsOtherUnits = true;
        };
    }
}
 