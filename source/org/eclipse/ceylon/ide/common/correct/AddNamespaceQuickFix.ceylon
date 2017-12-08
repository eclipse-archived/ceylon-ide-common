/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    UsageWarning,
    Warning
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}

"Adds missing `maven:` namespaces on deprecated Maven module imports:
 
     import \"org.hibernate:hibernate-core\" \"5.2.2.Final\";

 becomes

     import maven:\"org.hibernate:hibernate-core\" \"5.2.2.Final\";
 "
shared object addNamespaceQuickFix {
    
    shared void addProposal(QuickFixData data, UsageWarning warning ) {
        if (warning.warningName == Warning.missingImportPrefix.name()) {
            value change = platformServices.document.createTextChange {
                name = "Add Namespace";
                input = data.phasedUnit;
            };
            change.addEdit(InsertEdit(data.node.startIndex.intValue(), "maven:"));
            data.addQuickFix("Add 'maven:' namespace", change);
        }
    }
}
