/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
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
    ModelAliases,
    BaseIdeModuleSourceMapper
}
import org.eclipse.ceylon.ide.common.platform {
    ModelServicesConsumer
}
import org.eclipse.ceylon.ide.common.vfs {
    ZipEntryVirtualFile,
    ZipFileVirtualFile
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

import java.lang.ref {
    WeakReference
}
import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}

shared class CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> 
        extends ExternalPhasedUnit
        satisfies ModelServicesConsumer<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
                & ModelAliases<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
                & TypecheckerAliases<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
        given NativeProject satisfies Object
        given OriginalNativeResource satisfies Object
        given OriginalNativeFolder satisfies OriginalNativeResource
        given OriginalNativeFile satisfies OriginalNativeResource {
    
    WeakReference<CeylonProjectAlias> originalProjectRef;
    variable WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>> originalProjectPhasedUnitRef;
    
    shared new (
        ZipEntryVirtualFile unitFile, 
        ZipFileVirtualFile srcDir, 
        Tree.CompilationUnit cu, 
        Package p, 
        ModuleManager moduleManager, 
        BaseIdeModuleSourceMapper moduleSourceMapper, 
        TypeChecker typeChecker, 
        List<CommonToken> tokenStream, 
        CeylonProjectAlias originalProject) 
            extends ExternalPhasedUnit(unitFile, srcDir, 
                                       cu, p, 
                                       moduleManager, 
                                       moduleSourceMapper, 
                                       typeChecker, 
                                       tokenStream) {
        originalProjectRef 
                = WeakReference(originalProject);
        originalProjectPhasedUnitRef
                = WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>>(null);
    }
    
    shared new clone(CrossProjectPhasedUnitAlias other)
            extends ExternalPhasedUnit.clone(other) {
        originalProjectRef 
                = WeakReference(other.originalProjectRef.get());
        originalProjectPhasedUnitRef 
                = WeakReference(other.originalProjectPhasedUnit);
    }
    
    shared ProjectPhasedUnitAlias? originalProjectPhasedUnit {
        if (exists originalPhasedUnit 
                = originalProjectPhasedUnitRef.get()) {
            return originalPhasedUnit;
        } 
        if (exists originalProject = originalProjectRef.get(), 
            exists originalTypeChecker = originalProject.typechecker,
            is ProjectPhasedUnitAlias originalPhasedUnit 
                    = originalTypeChecker.getPhasedUnitFromRelativePath(
                            pathRelativeToSrcDir)) {
            originalProjectPhasedUnitRef 
                    = WeakReference<ProjectPhasedUnitAlias>
                        (originalPhasedUnit);
            return originalPhasedUnit;
        }
        return null;
    }
    
    /*shared actual IdeModuleSourceMapperAlias moduleSourceMapper 
            => unsafeCast<IdeModuleSourceMapperAlias>(super.moduleSourceMapper);*/
    
    shared actual TypecheckerUnit createUnit()
            => object satisfies ModelServicesConsumer<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>{
            }.modelServices.newCrossProjectSourceFile(this);
    
    /*shared actual CrossProjectSourceFileAlias unit 
            => unsafeCast<CrossProjectSourceFileAlias>(super.unit);*/
}
