/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.cmr.api {
    ArtifactContext,
    RepositoryManager
}
import org.eclipse.ceylon.compiler.java.loader.model {
    LazyModuleSourceMapper
}
import org.eclipse.ceylon.compiler.typechecker {
    TypeChecker
}
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    ModuleHelper,
    ModuleSourceMapper
}
import org.eclipse.ceylon.compiler.typechecker.context {
    Context,
    PhasedUnits
}
import org.eclipse.ceylon.compiler.typechecker.io {
    VirtualFile
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.compiler.typechecker.util {
    ModuleManagerFactory
}
import org.eclipse.ceylon.ide.common.model.parsing {
    CeylonSourceParser
}
import org.eclipse.ceylon.ide.common.typechecker {
    ExternalPhasedUnit,
    CrossProjectPhasedUnit,
    TypecheckerAliases
}
import org.eclipse.ceylon.ide.common.util {
    unsafeCast,
    equalsWithNulls
}
import org.eclipse.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile,
    BaseFileVirtualFile
}
import org.eclipse.ceylon.model.cmr {
    ArtifactResult
}
import org.eclipse.ceylon.model.typechecker.model {
    Module,
    ModuleImport,
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    File
}
import java.lang {
    Types {
        nativeString
    },
    JString=String
}
import java.util {
    List,
    LinkedList,
    ArrayList
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class ExternalModulePhasedUnits(Context context, ModuleManagerFactory moduleManagerFactory) 
        extends PhasedUnits(context, moduleManagerFactory) {
    shared formal void parseFileInPackage(VirtualFile file, VirtualFile srcDir, Package pkg);
}

shared abstract class BaseIdeModuleSourceMapper(Context theContext, BaseIdeModuleManager theModuleManager) 
        extends LazyModuleSourceMapper(theContext, theModuleManager, null, false, null) {
    
    theModuleManager.moduleSourceMapper = this;

    shared actual default BaseIdeModuleManager moduleManager {
        assert(is BaseIdeModuleManager mm=super.moduleManager);
        return mm;
    }

    shared actual Context context =>
            super.context;
    
    shared formal BaseCeylonProject? ceylonProject;
    shared variable late TypeChecker typeChecker;

    shared formal void logModuleResolvingError(BaseIdeModule theModule, Exception e);
    shared formal String defaultCharset;
    
    shared actual void resolveModule(
        variable ArtifactResult artifact, 
        Module theModule, 
        ModuleImport moduleImport, 
        LinkedList<Module> dependencyTree, 
        List<PhasedUnits> phasedUnitsOfDependencies, 
        Boolean forCompiledModule) {
        variable File artifactFile = artifact.artifact();
        if (ceylonProject?.loadInterProjectDependenciesFromSourcesFirst else false,
            moduleManager.searchForOriginalModule(theModule.nameAsString, artifactFile) exists) {
            moduleManager.sourceModules.add(theModule.nameAsString);
        }
        if (moduleManager.isModuleLoadedFromSource(theModule.nameAsString), 
            artifactFile.name.endsWith(ArtifactContext.car)) {
            value artifactContext = ArtifactContext(null, theModule.nameAsString, theModule.version, ArtifactContext.src);
            RepositoryManager repositoryManager = context.repositoryManager;
            variable Exception? exceptionOnGetArtifact = null;
            variable ArtifactResult? sourceArtifact = null;
            try {
                sourceArtifact = repositoryManager.getArtifactResult(artifactContext);
            }
            catch (e) {
                exceptionOnGetArtifact = e;
            }
            if (exists existingSourceArtifact=sourceArtifact) {
                artifact = existingSourceArtifact;
            }
            else {
                ModuleHelper.buildErrorOnMissingArtifact(artifactContext, theModule, moduleImport, dependencyTree, exceptionOnGetArtifact, this, true);
            }
        }
        if (is BaseIdeModule theModule) {
            theModule.setArtifactResult(artifact);
        }
        if (equalsWithNulls(artifact.namespace(), "npm")) {
            moduleManager.sourceModules.add(theModule.nameAsString);
            return;
        }
        
        if (!moduleManager.isModuleLoadedFromCompiledSource(theModule.nameAsString)) {
            variable File file = artifact.artifact();
            if (artifact.artifact().name.endsWith(".src")) {
                moduleManager.sourceModules.add(theModule.nameAsString);
                file = File(nativeString(file.absolutePath).replaceAll("\\.src$", ".car"));
            }
        }
        try {
            if (forCompiledModule || theModule == theModule.languageModule || moduleManager.shouldLoadTransitiveDependencies(),
                artifact.artifact().name.lowercased.endsWith(".js")) {

                // Sometimes the CMR will return a .js file if .car and .src are missing
                // (the repo contains xxxx.car.missing and xxxx.src.missing). In that case, we avoid
                // adding the artifact to the classpath.
                return;
            }
            super.resolveModule(artifact, theModule, moduleImport, dependencyTree, phasedUnitsOfDependencies, forCompiledModule);
        }
        catch (e) {
            if (is BaseIdeModule theModule) {
                logModuleResolvingError(theModule, e);
                theModule.setResolutionException(e);
            }
        }
    }
    
    shared actual void visitModuleFile() {
        value currentPkg = currentPackage;
        moduleManager.sourceModules.add(currentPkg.nameAsString);
        super.visitModuleFile();
    }
    
    shared void addTopLevelModuleError() {
        addErrorToModule(ArrayList<JString>(), "A module cannot be defined at the top level of the hierarchy");
    }
    
    shared actual formal ExternalModulePhasedUnits createPhasedUnits();
    
    shared actual void addToPhasedUnitsOfDependencies(
        PhasedUnits modulePhasedUnits, 
        List<PhasedUnits> phasedUnitsOfDependencies, 
        Module mod) {
        super.addToPhasedUnitsOfDependencies(modulePhasedUnits, phasedUnitsOfDependencies, mod);
        if (is BaseIdeModule mod) {
            assert(is ExternalModulePhasedUnits modulePhasedUnits);
            mod.setSourcePhasedUnits(modulePhasedUnits);
        }
    }
    
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
shared abstract class IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>(
    Context context, 
    IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> theModuleManager) 
        extends BaseIdeModuleSourceMapper(context, theModuleManager) 
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual CeylonProjectAlias? ceylonProject => theModuleManager.ceylonProject;
    
    shared actual default IdeModuleManagerAlias moduleManager =>
            unsafeCast<IdeModuleManagerAlias>(super.moduleManager);
    
    value currentSourceMapper => this;
    
    shared actual ExternalModulePhasedUnits createPhasedUnits() {
        ModuleManagerFactory moduleManagerFactory = object satisfies ModuleManagerFactory {
            
            shared actual ModuleManager createModuleManager(variable Context context) {
                return moduleManager;
            }
            
            shared actual ModuleSourceMapper createModuleManagerUtil(variable Context context, variable ModuleManager moduleManager) {
                return currentSourceMapper;
            }
            
        };
        return object extends ExternalModulePhasedUnits(context, moduleManagerFactory) {
            
            variable CeylonProjectAlias? referencedProject = null;
            
            shared actual void parseFile(VirtualFile file, VirtualFile srcDir) {
                if (file.name.endsWith(".ceylon")) {
                    parseFileInPackage(file, srcDir, currentSourceMapper.currentPackage);
                }
            }
            
            shared actual void parseFileInPackage(VirtualFile file, VirtualFile srcDir, Package pkg) {
                assert(is ZipEntryVirtualFile zipEntry=file);
                assert(is ZipFileVirtualFile zipArchive=srcDir);
                value sourceParser = object satisfies CeylonSourceParser<ExternalPhasedUnit> {
                    createPhasedUnit(
                        Tree.CompilationUnit cu,
                        Package pkg,
                        List<CommonToken> tokens) => 
                            if (exists rp=referencedProject) 
                    then CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
                            zipEntry, 
                            zipArchive, 
                            cu, 
                            pkg, 
                            moduleManager, 
                            currentSourceMapper, 
                            typeChecker, 
                            tokens, 
                            rp) 
                    else ExternalPhasedUnit(
                                zipEntry, 
                                zipArchive, 
                                cu, 
                                pkg, 
                                moduleManager, 
                                currentSourceMapper, 
                                typeChecker, 
                                tokens);
                    
                    charset(BaseFileVirtualFile file) => 
                            /* TODO: is this correct? does this file actually
                              live in the project, or is it external?
                              should VirtualFile have a getCharset()? */
                            ceylonProject?.defaultCharset else defaultCharset;
                };
                value phasedUnit = sourceParser.parseFileToPhasedUnit(moduleManager, typeChecker, zipEntry, zipArchive, pkg);
                addPhasedUnit(file, phasedUnit);
            }
            
            shared actual void parseUnit(variable VirtualFile srcDir) {
                if (srcDir is ZipFileVirtualFile, exists p=ceylonProject) {
                    assert(is ZipFileVirtualFile zipFileVirtualFile = srcDir);
                    String archiveName = zipFileVirtualFile.path;
                    for (refProject in p.referencedCeylonProjects) {
                        if (refProject.ceylonModulesOutputDirectory.absolutePath in archiveName) {
                            referencedProject = refProject;
                            break;
                        }
                    }
                }
                super.parseUnit(srcDir);
            }
        };
    }
}

