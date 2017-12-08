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
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}

shared object removeUnusedDeclarationQuickFix {

    shared void addProposal(QuickFixData data, UsageWarning warning) {
        if (warning.warningName == Warning.unusedDeclaration.name(),
            exists decl = nodes.findDeclaration(data.rootNode, data.node)) {

            value change = platformServices.document.createTextChange {
                name = "Remove Unused Declaration";
                input = data.phasedUnit;
            };
            
            variable value declStart = decl.startIndex.intValue();
            variable value declStop = decl.stopIndex.intValue();
            
            // Also removes whitespace before the declaration
            value startLine = data.document.getLineOfOffset(declStart);
            value startOfStartLine = data.document.getLineStartOffset(startLine);
            value beforeStart = data.document.getText {
                offset = startOfStartLine;
                length = declStart - startOfStartLine;
            };
            if (beforeStart.trimmed.empty) {
                declStart = startOfStartLine;
            }
            
            // Also removes whitespace on the same line, after the declaration
            value stopLine = data.document.getLineOfOffset(declStop);
            value stopOfStopLine = data.document.getLineEndOffset(stopLine);
            value afterStop = data.document.getText {
                offset = declStop;
                length = stopOfStopLine - declStop;
            };
            if (afterStop.trim((c) => !c in ['\n', '\t', ' ']).empty) {
                declStop += afterStop.size;
            }
            
            change.addEdit(DeleteEdit(declStart, declStop - declStart + 1));

            data.addQuickFix {
                description = "Removed unused declaration '``decl.declarationModel.name``'";
                change = change;
                image = Icons.remove;
            };
        }
    }
}