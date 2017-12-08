/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.io {
    VirtualFile
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    EditedSourceFile,
    ProjectSourceFile
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit,
    Declaration
}

Boolean descriptor(VirtualFile sourceFile) 
        => sourceFile.name == "module.ceylon" ||
        sourceFile.name == "package.ceylon";

Boolean editable(Unit? unit)
        => unit is EditedSourceFile<in Nothing, in Nothing, in Nothing, in Nothing> |
                   ProjectSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;

shared interface AbstractRefactoring<RefactoringData> 
        satisfies Refactoring {
    
    shared interface EditorData {
        shared formal List<CommonToken> tokens;
        shared formal Tree.CompilationUnit rootNode;
        shared formal Node node;
        shared formal VirtualFile? sourceVirtualFile;
    }

    shared formal EditorData editorData;

    shared formal List<PhasedUnit> getAllUnits();
    shared formal PhasedUnit editorPhasedUnit;
    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Boolean inSameProject(Declaration decl);
    shared default Tree.CompilationUnit rootNode => editorData.rootNode;

    shared Tree.Term unparenthesize(Tree.Term term) {
        if (is Tree.Expression term, !is Tree.Tuple t = term.term) {
            return unparenthesize(term.term);
        }
        return term;
    }
    
    shared formal Boolean affectsOtherFiles;
    
    shared default Integer countDeclarationOccurrences() {
        variable Integer count = 0;
        if (affectsOtherFiles) {
            for (pu in getAllUnits()) {
                if (searchInFile(pu)) {
                    count += countReferences(pu.compilationUnit);
                }
            }
        }
        if (!affectsOtherFiles || searchInEditor()) {
            count += countReferences(rootNode);
        }
        return count;
    }

    shared default Integer countReferences(Tree.CompilationUnit cu) => 0;

    shared formal Anything build(RefactoringData refactoringData);
}