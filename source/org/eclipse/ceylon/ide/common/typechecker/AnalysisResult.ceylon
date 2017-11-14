/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker {
    TypeChecker
}
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    BaseCeylonProject
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}
import java.util.concurrent {
    Future
}


"The result of the parsing / typechecking of a PhasedUnit."
shared interface AnalysisResult {

    "The document of the most-recently parsed AST"
    shared formal CommonDocument commonDocument;

    "The token stream of the most-recently parsed AST"
    shared formal List<CommonToken> tokens;

    "Most recently parsed AST.

     __Be careful__ it can be returned *before* the typechecking or
     *during* the typechecking (in case of cancellation).
     So *never* use this from places that need a fully typechecked AST
     (with model elements such as declarations or units)."
    shared formal Tree.CompilationUnit parsedRootNode;

    "The typechecker used during the last typecheck.
     Can be [[null]] if no typechecking was performed"
    shared formal TypeChecker? typeChecker;

    """Returns the most-recently parsed AST ([[parsedRootNode]])
       only if it is fully typechecked,
       or [[null]] if the most-recently parsed AST could not be fully
       typechecked
       (cancellation, source model read lock not obtained,
       running typechecking ...).
       It is a shotcut for:

            typecheckedPhasedUnit?.compilationUnit

       """
    shared Tree.CompilationUnit? typecheckedRootNode =>
            typecheckedPhasedUnit?.compilationUnit;

    "The typechecked [[PhasedUnit]] built on the most-recently parsed AST.
     or [[null]] if the most-recently parsed AST could not be fully
     typechecked
     (cancellation, source model read lock not obtained,
     running typechecking ...)"
    shared formal PhasedUnit? typecheckedPhasedUnit;

    "The future that allows waiting for the typechecked [[PhasedUnit]]
     built on the most-recently parsed AST ([[parsedRootNode]])."
    shared formal Future<out PhasedUnit> phasedUnitWhenTypechecked;

    "The [[BaseCeylonProject]] of this document.
     Can be [[null]] for non-physical documents
     such as VCS document version,
     comparison editor documents, etc..."
    shared formal BaseCeylonProject? ceylonProject;

    shared Boolean upToDate => typecheckedRootNode exists;
}