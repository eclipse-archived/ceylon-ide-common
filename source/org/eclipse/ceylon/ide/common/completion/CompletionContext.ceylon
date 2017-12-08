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
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.settings {
    CompletionOptions
}
import org.eclipse.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}

import java.util.regex {
    Pattern
}
import org.eclipse.ceylon.compiler.typechecker {
    TypeChecker
}

shared interface CompletionContext satisfies LocalAnalysisResult {
    shared formal ProposalsHolder proposals;
    shared formal CompletionOptions options;
    shared formal List<Pattern> proposalFilters; // TODO put in options?

    "The last fully-typechecked AST. It might be different 
     from the most recently parsed AST, and thus inconsistent
     with the source code.
     
     Unlike [[LocalAnalysisResult.lastCompilationUnit]], it canot be [[null]]
     because completion is expected to be started only on documents that have 
     been typechecked at least once."
    shared actual formal Tree.CompilationUnit lastCompilationUnit;

    "The last typechecked [[PhasedUnit]].
     
     The associated AST might be different from the most 
     recently parsed AST, and thus inconsistent with the source code.
     
     Unlike [[LocalAnalysisResult.lastPhasedUnit]], it canot be [[null]]
     because completion is expected to be started only on documents that have 
     been typechecked at least once."
    shared actual formal PhasedUnit lastPhasedUnit;
    
    "The typechecker used during the last typecheck.
     
     Unlike [[LocalAnalysisResult.typeChecker]], it canot be [[null]]
     because completion is expected to be started only on documents that have 
     been typechecked at least once."
    shared actual formal TypeChecker typeChecker;
}

"A store for native completion proposals, usually baked by an ArrayList of:
 
 * `ICompletionProposal` on Eclipse
 * `LookupElement` on IntelliJ
 "
shared interface ProposalsHolder {
    shared formal Integer size;
    shared Boolean empty => size == 0;
}