import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning,
    Warning
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared object removeUnusedDeclarationQuickFix {

    shared void addProposal(QuickFixData data, UsageWarning warning) {
        if (warning.warningName == Warning.unusedDeclaration.name(),
            exists decl = nodes.findDeclaration(data.rootNode, data.node)) {

            value change = platformServices.document.createTextChange {
                name = "Remove unused declaration";
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