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
    TypecheckerUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    ExternalSourceFile,
    BaseIdeModuleSourceMapper,
    CeylonUnit
}
import org.eclipse.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared class ExternalPhasedUnit extends IdePhasedUnit {
    
    ZipEntryVirtualFile _unitFile;
    ZipFileVirtualFile _srcDir;
    
    shared new (ZipEntryVirtualFile unitFile, ZipFileVirtualFile srcDir,
        Tree.CompilationUnit cu, Package p, ModuleManager moduleManager,
        BaseIdeModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker, JList<CommonToken> tokenStream) 
            extends IdePhasedUnit(
            unitFile, 
            srcDir, 
            cu, 
            p, 
            moduleManager, 
            moduleSourceMapper, 
            typeChecker, 
            tokenStream) {
        this._unitFile = unitFile;
        this._srcDir = srcDir;
    }
    
    shared new clone(ExternalPhasedUnit other) 
            extends IdePhasedUnit.clone(other) {
        this._srcDir = other.srcDir;
        this._unitFile = other.unitFile;
    }
    
    shared actual default TypecheckerUnit createUnit() 
            => ExternalSourceFile(this);
    
    shared actual CeylonUnit unit {
        assert (is CeylonUnit unit = super.unit);
        return unit;
    }
    
    shared actual ZipFileVirtualFile srcDir => _srcDir;
    shared actual ZipEntryVirtualFile unitFile => _unitFile;
    
}