/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
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
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
shared object fixAliasQuickFix {
    
    shared void addFixAliasProposal(QuickFixData data) {
        value offset = data.problemOffset;
        value change 
                = platformServices.document.createTextChange {
            name = "Fix Alias Syntax";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        change.addEdit(ReplaceEdit(offset, 1, "=>"));
        
        data.addQuickFix {
            description = "Change = to =>";
            change = change;
            selection = DefaultRegion(offset + 2);
        };
    }
}
