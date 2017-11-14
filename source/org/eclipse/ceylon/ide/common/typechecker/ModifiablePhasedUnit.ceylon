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
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    IResourceAware,
    ModelAliases,
    BaseIdeModuleSourceMapper
}
import org.eclipse.ceylon.ide.common.vfs {
    FileVirtualFile,
    FolderVirtualFile,
    VfsAliases
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends IdePhasedUnit
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
        & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> _unitFile;
    FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> _srcDir;
    
    shared new (
        FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> unitFile, 
        FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> srcDir, 
        Tree.CompilationUnit cu, Package p, ModuleManager moduleManager, 
        BaseIdeModuleSourceMapper moduleSourceMapper, 
        TypeChecker typeChecker, 
        List<CommonToken> tokenStream)
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

    shared new clone(ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> other) 
            extends IdePhasedUnit.clone(other) {
        this._unitFile = other.unitFile;
        this._srcDir = other.srcDir;
    }
    
    /*shared actual IdeModuleSourceMapperAlias moduleSourceMapper => 
            unsafeCast<IdeModuleSourceMapperAlias>(super.moduleSourceMapper);*/
    
    shared actual FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> unitFile => _unitFile;
    shared actual FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir => _srcDir;
}

