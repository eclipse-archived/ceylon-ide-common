/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.interop.java {
    JavaList
}
import java.lang {
    Types {
        nativeString
    }
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    BaseIdeModule,
    CeylonProject
}
import org.eclipse.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
}
import org.eclipse.ceylon.ide.common.util {
    BaseProgressMonitor
}
import org.eclipse.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile
}
import org.eclipse.ceylon.model.typechecker.model {
    Module,
    Package,
    Declaration
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

shared class ModulesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
            CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> ceylonProject,
            FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir,
            BaseProgressMonitor.Progress progress)
        extends RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
                ceylonProject,
                srcDir,
                progress
            )
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    shared actual ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> parser(
        FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> moduleFile) =>
            object extends ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> (
            outer.ceylonProject,
            moduleFile,
            outer.rootDir) {
        createPhasedUnit(
            Tree.CompilationUnit cu,
            Package pkg,
            JList<CommonToken> theTokens)
                => object extends ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
                outer.ceylonProject,
                moduleFile,
                outer.srcDir,
                cu,
                pkg,
                moduleManager,
                moduleManager.moduleSourceMapper,
                moduleManager.typeChecker,
                theTokens) {
            isAllowedToChangeModel(Declaration? declaration) 
                    => false;
        };
    };
    
    shared actual Boolean visitNativeResource(NativeResource resource) {
        progress.updateRemainingWork(10000);
        progress.worked(1);
        if (is NativeFolder resource,
            resource == nativeRootDir) {
            value moduleFile = vfsServices.findFile(resource, ModuleManager.moduleFile);
            if (exists moduleFile) {
                moduleSourceMapper.addTopLevelModuleError();
            }
            return true;
        }

        if (exists parent = vfsServices.getParent(resource),
            parent == nativeRootDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
        }

        if (vfsServices.isFolder(resource)) {
            assert(is NativeFolder resource);
            value pkgName = vfsServices.toPackageName(resource, nativeRootDir);
            value pkgNameAsString = ".".join(pkgName);

            if ( currentModule != defaultModule ) {
                if (! pkgNameAsString.startsWith(currentModule.nameAsString + ".")) {
                    // We've ran above the last module => reset module to default
                    currentModule = defaultModule;
                }
            }

            value moduleFile = vfsServices.findFile(resource, ModuleManager.moduleFile);
            if (exists moduleFile) {
                // First create the package with the default module and we'll change the package
                // after since the module doesn't exist for the moment and the package is necessary
                // to create the PhasedUnit which in turns is necessary to create the module with the
                // right version from the beginning (which is necessary now because the version is
                // part of the Module signature used in equals/has methods and in caching
                // The right module will be set when calling findOrCreatePackage() with the right module
                value pkg = Package();

                pkg.name = JavaList(pkgName.map((String s)=> nativeString(s)).sequence());

                try {
                    value moduleVirtualFile = vfsServices.createVirtualFile(moduleFile, ceylonProject.ideArtifact);
                    value tempPhasedUnit = parser(moduleVirtualFile).parseFileToPhasedUnit(moduleManager, typeChecker, moduleVirtualFile, srcDir, pkg);

                    Module? m = tempPhasedUnit.visitSrcModulePhase();
                    if (exists m) {
                        assert(is BaseIdeModule m);
                        currentModule = m;
                        currentModule.isProjectModule = true;
                    }
                }
                catch (e) {
                    e.printStackTrace();
                }
            }

            if (currentModule != defaultModule) {
                // Creates a package with this module only if it's not the default
                // => only if it's a *ceylon* module
                modelLoader.findOrCreatePackage(currentModule, pkgNameAsString);
            }
            return true;
        }
        return false;
    }
}