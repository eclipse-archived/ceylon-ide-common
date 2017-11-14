/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
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


"The result of the local typechecking of a CompilationUnit.
 For example, this can be used when a file is being modified,
 but the resulting PhasedUnit should not be added to the global model."
shared interface LocalAnalysisResult satisfies AnalysisResult {

    "The last typechecked [[PhasedUnit]].
     
     The associated AST might be different from the most 
     recently parsed AST,
     and thus inconsistent with the source code.
     
     It can be [[null]] if not typechecking ever occured
     on this document."
    shared formal PhasedUnit? lastPhasedUnit;
    
    "The last fully-typechecked AST.
     It might be different from the most recently parsed AST,
     and thus inconsistent with the source code
     
     It can be [[null]] if not typechecking ever occured
     on this document."
    shared default Tree.CompilationUnit? lastCompilationUnit =>
            lastPhasedUnit?.compilationUnit;
}