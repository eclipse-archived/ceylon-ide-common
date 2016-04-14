import ceylon.collection {
    HashSet,
    unlinked,
    LinkedList
}
import ceylon.interop.java {
    synchronize,
    CeylonIterable,
    JavaList
}

import com.redhat.ceylon.common {
    Backend,
    FileUtil
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.model.parsing {
    ProjectSourceParser
}
import com.redhat.ceylon.ide.common.platform {
    VfsServicesConsumer,
    platformUtils
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    ImmutableMapWrapper,
    ImmutableSetWrapper,
    Path,
    BaseProgressMonitor,
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Module
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    File
}

shared final class Severity
        of info | warning | error
        satisfies Comparable<Severity> {
    Integer ordinal;
    shared new info {ordinal=0;}
    shared new warning {ordinal=1;}
    shared new error {ordinal=2;}
    
    compare(Severity other) => 
            ordinal <=> other.ordinal;
    equals(Object that) =>
            if (is Severity that)
    then ordinal==that.ordinal
    else false;
}


shared class CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>(ceylonProject)
        satisfies ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    CeylonProjectAlias ceylonProject;
    
    shared class State() {
        "Unanalyzed changes added since the last time [[analyzeChanges]] was called.
         The list is filled by [[fileTreeChanged]] and flushed for use by [[analyzeChanges]]"
        shared ImmutableSetWrapper<ChangeToAnalyze> fileChangesToAnalyze = ImmutableSetWrapper<ChangeToAnalyze>();
        
        "Model changes since the last time [[consumeModelChanges]] was called.
         The list is filled by [[analyzeChanges]] and flushed for use by [[consumeModelChanges]]"
        shared ImmutableSetWrapper<ResourceVirtualFileChange> modelFileChanges = ImmutableSetWrapper<ResourceVirtualFileChange>();
        
        "Sources requiring a typechecking during the next [[updateCeylonModel]] call.
         The list is filled by [[consumeModelChanges]] and flushed for use by [[updateCeylonModel]]"
        shared ImmutableSetWrapper<NativeFile> ceylonModelUpdateRequired = ImmutableSetWrapper<NativeFile>();
        
        "Sources requiring a JVM binary generation during the next [[performBinaryGeneration]] call.
         The list is filled by [[consumeModelChanges]] and flushed for use by [[performBinaryGeneration]]"
        shared ImmutableSetWrapper<NativeFile> jvmBackendGenerationRequired = ImmutableSetWrapper<NativeFile>();
        
        shared ImmutableSetWrapper<SourceFileError> backendErrors = ImmutableSetWrapper<SourceFileError>();
        shared ImmutableSetWrapper<SourceFileError> frontendErrors = ImmutableSetWrapper<SourceFileError>();
        shared ImmutableSetWrapper<ProjectError> projectErrors = ImmutableSetWrapper<ProjectError>();
        
        shared ImmutableMapWrapper<NativeFile,Set<String>> missingClasses = ImmutableMapWrapper<NativeFile,Set<String>>();
        
        shared class BuildTypeState() {
            variable Boolean _fullBuildRequested = true;
            variable Boolean _classpathResolutionRequested = true;
            
            variable Boolean _fullBuildRequired = false;
            variable Boolean _classpathResolutionRequired = false;
            
            variable Boolean _fullBuildPlanned = false;
            variable Boolean _classpathResolutionPlanned = false;
            
            shared void requestFullBuild() => synchronize(this, () {
                _fullBuildRequested = true;
            });
            
            shared void requestClasspathResolution() => synchronize(this, () {
                _classpathResolutionRequested = true;
            });
            
            shared void acceptRequests() => synchronize(this, () {
                if (_fullBuildRequested) {
                    _fullBuildRequired = true; 
                    _fullBuildRequested = false; 
                }
                if (_classpathResolutionRequested) {
                    _classpathResolutionRequired = true; 
                    _classpathResolutionRequested = false; 
                }
            });
            
            shared void requireFullBuild() => synchronize(this, () {
                _fullBuildRequired = true;
            });
            
            shared void requireClasspathResolution() => synchronize(this, () {
                _classpathResolutionRequired = true;
            });
            
            shared void planBuildTypes() => synchronize(this, () {
                if (_fullBuildRequired) {
                    _fullBuildPlanned = true; 
                    _fullBuildRequired = false; 
                }
                if (_classpathResolutionRequired) {
                    _classpathResolutionPlanned = true; 
                    _classpathResolutionRequired = false; 
                }
            });
            
            shared Boolean fullBuildRequired =>
                    _fullBuildRequired;
            
            shared Boolean classpathResolutionRequired =>
                    _classpathResolutionRequired;
            
            shared Boolean fullBuildPlanned =>
                    _fullBuildPlanned;
            
            shared Boolean classpathResolutionPlanned =>
                    _classpathResolutionPlanned;
            
            shared void resetClasspathResolution() => synchronize(this, () {
                _classpathResolutionPlanned = false;
            });
            
            shared void resetFullBuild() => synchronize(this, () {
                _fullBuildPlanned = false;
            });
        }
        
        shared BuildTypeState buildType = BuildTypeState();
    }
    
    State state = State();
    
    shared abstract class BuildMessage(String theMessage, Backend theBackend=Backend.\iHeader) 
            of ProjectMessage | SourceFileMessage {
        shared String message = theMessage;
        shared Backend backend = theBackend;
        shared formal Severity severity;
        
        shared actual formal Boolean equals(Object that);
    }
    
    shared abstract class ProjectMessage(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            of ProjectWarning | ProjectError
            extends BuildMessage(theMessage, theBackend) {
        shared NativeProject project = theProject;
        
        shared actual Boolean equals(Object that) {
            if (is ProjectMessage that) {
                return message==that.message && 
                        backend==that.backend && 
                        backend==that.severity && 
                        project==that.project;
            }
            else {
                return false;
            }
        }
        
        shared actual Integer hash {
            variable value hash = 1;
            hash = 31*hash + message.hash;
            hash = 31*hash + backend.hash;
            hash = 31*hash + project.hash;
            hash = 31*hash + severity.hash;
            return hash;
        }
    }
    
    shared abstract class ProjectError(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            extends ProjectMessage(theMessage, theProject, theBackend) {
        severity = Severity.error;
    }
    
    shared abstract class ProjectWarning(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            extends ProjectMessage(theMessage, theProject, theBackend) {
        severity = Severity.warning;
    }
    
    shared abstract class SourceFileMessage (
        String theMessage,
        NativeFile theFile,
        Backend theBackend=Backend.\iHeader)  
            of SourceFileWarning | SourceFileError
            extends BuildMessage(theMessage, theBackend) {
        shared NativeFile file = theFile;
        
        shared actual Boolean equals(Object that) {
            if (is SourceFileMessage that) {
                return message==that.message && 
                        backend==that.backend && 
                        backend==that.severity && 
                        file==that.file;
            }
            else {
                return false;
            }
        }
        
        shared actual Integer hash {
            variable value hash = 1;
            hash = 31*hash + message.hash;
            hash = 31*hash + backend.hash;
            hash = 31*hash + file.hash;
            hash = 31*hash + severity.hash;
            return hash;
        }
    }
    
    shared abstract class SourceFileError(
        String theMessage, 
        NativeFile theFile,
        Backend theBackend=Backend.\iHeader)
            extends SourceFileMessage(theMessage, theFile, theBackend) {
        severity = Severity.error;
    }
    
    shared abstract class SourceFileWarning(
        String theMessage,
        NativeFile theFile,
        Backend theBackend=Backend.\iHeader)
            extends SourceFileMessage(theMessage, theFile, theBackend) {
        severity = Severity.warning;
    }
    
    shared Set<SourceFileMessage> backendErrors => state.backendErrors.immutable;
    shared Set<SourceFileMessage> frontendErrors => state.frontendErrors.immutable;
    shared {SourceFileMessage*} sourceFileErrors => state.frontendErrors.immutable.chain(state.backendErrors.immutable);
    shared Set<ProjectMessage> projectErrors => state.projectErrors.immutable;
    shared {BuildMessage*} errors => sourceFileErrors.chain(state.projectErrors.immutable);
    
    shared {SourceFileMessage*} errorsForSourceFile(NativeFile file) => 
            sourceFileErrors.filter((error) => error.file == file);
    
    shared Boolean sourceFileHasErrors(NativeFile file, Boolean searchedSeverity(Severity severity) => true) =>
            errorsForSourceFile(file)
            .any((message) => searchedSeverity(message.severity));
    
    shared Map<NativeFile,Set<String>> missingClasses => state.missingClasses.immutable;
    
    shared void classPathChanged() {
        state.buildType.requestFullBuild();
    }
    
    shared void requestFullBuild() {
        state.buildType.requestFullBuild();
        state.buildType.requestClasspathResolution();
    }
    
    shared void requestCleanBuild() {
        state.buildType.requestFullBuild();
    }
    
    "Returns [[true]] if the change analysis has been correctly done,
     or [[false]] if the change analysis has been cancelled due to
     critical errors that would make the upcoming build impossible or pointless."
    shared Boolean analyzeChanges(BaseProgressMonitor monitor) {
        variable Boolean success = false;
        try(progress = monitor.Progress(1000, "Analyzing changes for project `` ceylonProject.name ``")) {
            value changesToAnalyze = state.fileChangesToAnalyze.clear();
            state.buildType.acceptRequests();
            
            if (! ceylonProject.parsed) {
                state.buildType.requireFullBuild();
            }
            
            value astAwareIncrementalBuild = true;
            
            // get the modules
            value outputRepoMap = map(ceylonProject.referencedCeylonProjects
                .follow(ceylonProject)
                    .map((project) => 
                project.ideArtifact -> [ 
            Path(project.configuration.outputRepoProjectRelativePath),
            vfsServices.fromJavaFile(project.configuration.projectConfigFile, project.ideArtifact),
            vfsServices.fromJavaFile(project.ideConfiguration.ideConfigFile, project.ideArtifact)
            ]));
            
            value overridesResource =
                    if (exists overridesFilePath = ceylonProject.configuration.overrides,
                exists overridesFile = FileUtil.absoluteFile(FileUtil.applyCwd(ceylonProject.rootDirectory, File(overridesFilePath))))
            then vfsServices.fromJavaFile(overridesFile, ceylonProject.ideArtifact)
            else null;
            
            for (change in changesToAnalyze) {
                switch(change)
                case(is [NativeResourceChange, NativeProject]) {
                    // Change outside project sources or resources
                    value [nonModelChange, changeProject] = change;
                    value resource = nonModelChange.resource;
                    switch(nonModelChange)
                    case(is NativeFolderRemoval) {
                        if (exists relativePath = vfsServices.getProjectRelativePath(resource, ceylonProject),
                            exists [outputRepo, _, __] = outputRepoMap.get(changeProject),
                            outputRepo.isPrefixOf(relativePath)) {
                            state.buildType.requireFullBuild();
                            state.buildType.requireClasspathResolution();
                        }
                    }
                    case(is NativeFileChange) {
                        if (exists overridesResource, 
                            resource == overridesResource) {
                            state.buildType.requireFullBuild();
                            state.buildType.requireClasspathResolution();
                        }
                        if (exists [_, configResource, ideConfigResource] = outputRepoMap.get(changeProject)) {
                            if (exists configResource,
                                resource == configResource) {
                                state.buildType.requireFullBuild();
                                state.buildType.requireClasspathResolution();
                            }
                            if (exists ideConfigResource,
                                resource == ideConfigResource) {
                                state.buildType.requireFullBuild();
                                state.buildType.requireClasspathResolution();
                            }
                        }
                    }
                    else {}
                    
                }
                case(is ResourceVirtualFileChange) {
                    // Change in project sources or resources
                    switch(change)
                    case(is FolderVirtualFileRemoval) {
                        // Check if a folder with an existing package is removed
                        if (change.resource.ceylonPackage exists) {
                            state.buildType.requireFullBuild();
                        }
                    }
                    case(is FileVirtualFileChange) {
                        // Check if a *source file* module descriptor or package descriptor is changed ( ast no changes + errors, etc ...)
                        value file = change.resource;
                        if (exists isInSourceFolder = file.isSource,
                            isInSourceFolder) {
                            value fileName = file.name;
                            if (fileName == ModuleManager.\iPACKAGE_FILE || 
                                fileName == ModuleManager.\iMODULE_FILE) {
                                
                                //a package or module descriptor has been added, removed, or changed
                                if (astAwareIncrementalBuild,
                                    file.\iexists(),
                                    ! sourceFileHasErrors(file.nativeResource, Severity.error.equals),
                                    is ProjectSourceFileAlias projectSourceFile = file.unit,
                                    exists delta = projectSourceFile.buildDeltaAgainstModel(),
                                    delta.changes.empty,
                                    delta.childrenDeltas.empty) {
                                    
                                    // Descriptor didn't change significantly => don't request a full build
                                } else {
                                    
                                    state.buildType.requireFullBuild();
                                    if (fileName == ModuleManager.\iMODULE_FILE) {
                                        state.buildType.requireClasspathResolution();
                                    }
                                }
                            }
                        }
                        
                    }
                    else {}
                }
            }
            
            success = ceylonProject.buildHooks.every((hook) => hook.analyzingChanges(changesToAnalyze, this, state));
            
            state.modelFileChanges.addAll(changesToAnalyze.narrow<ResourceVirtualFileChange>());
            state.buildType.planBuildTypes();
            success = true;
        } finally {
            if (!success) {
                state.buildType.requestFullBuild();
                state.buildType.requestClasspathResolution();
            }
        }
        return success;
    }
    
    shared void fileTreeChanged({<[NativeResourceChange, NativeProject]|ResourceVirtualFileChange>+} changes) {
        state.fileChangesToAnalyze.addAll(changes); 
    }
    
    shared Boolean performBuild(BaseProgressMonitor monitor) {
        variable Boolean finished = false;
        try(progress = monitor.Progress(1000, "Ceylon build of project `` ceylonProject.name ``")) {
            // should do pre-build checks
            if (!analyzeChanges(progress.newChild(100))) {
                return false;
            }
            
            if (state.buildType.classpathResolutionPlanned || state.buildType.fullBuildPlanned) {
                // TODO this should be factorized in a dedicated method called resolveClasspath
                // that would be decorated with before and after hooks (tomanage the case of 
                // Eclipe classpath container resolving
                ceylonProject.parseCeylonModel(progress.newChild(100));
                state.buildType.resetClasspathResolution();
            }
            
            if (! state.buildType.fullBuildPlanned && 
                ! ceylonProject.typechecked) {
                // Do a full typecheck to populate the Ceylon model.
                withCeylonModelCaching {
                    void do() {
                        ceylonProject.withSourceModel(false, void () {
                            typecheckDependencies(progress.newChild(100));
                            initializeLanguageModule(progress.newChild(100));
                            typecheck(monitor, ceylonProject.parsedUnits);
                        }, 20);
                    }
                };
            }
            
            consumeModelChanges(progress.newChild(500));
            
            updateCeylonModel(progress.newChild(500));
            
            if (state.ceylonModelUpdateRequired.empty && state.jvmBackendGenerationRequired.empty) {
                return true;
            }
            
            progress.updateRemainingWork(800);
            performBinaryGeneration(progress.newChild(300));
            finished = true;
        } finally {
            if (!finished) {
                state.buildType.requestFullBuild();
                state.buildType.requestClasspathResolution();
            }
        }
        return finished;
    }
    
    void typecheckingStep({PhasedUnit*} phasedUnits, BaseProgressMonitor.Progress progress)(void phase(PhasedUnit pu), String subTaskPrefix, Integer ticks) {
        for (pu in phasedUnits) {
            progress.subTask(subTaskPrefix + " for file " + pu.unit.filename);
            phase(pu);
            if (progress.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            progress.worked(ticks);
        }
    }
    
    void typecheck(BaseProgressMonitor monitor, {ProjectPhasedUnitAlias*} phasedUnitsToTypecheck) {
        value numberOfPhasedUnits = phasedUnitsToTypecheck.size;
        try(progress = monitor.Progress(numberOfPhasedUnits * 8, "Typechecking `` numberOfPhasedUnits `` source files of project `` ceylonProject.name ``")) {
            value files = phasedUnitsToTypecheck.map((pu) => pu.resourceFile).sequence();
            // remove the non-backend project errors
            state.projectErrors.clear();
            // remove the non-backend errors on the files corresponding to 
            state.frontendErrors.removeEvery((error) => error.file in files);
            
            // TODO : remove tasks (we should first define tasks in the build state...)
            
            // TODO : Typecheck all the phases on the given phased units
            // TODO : BEWARE - the phased are not exactly the same for full build and incremental build...
            //   => we might need to separate in 2 functions...
            
            // TODO : collect dependencies
            
            // TODO : add problems and tasks
        }
    }
    
    void refreshCeylonArchives(BaseProgressMonitor monitor) {
        assert(exists modules = ceylonProject.modules,
            exists typeChecker = ceylonProject.typechecker);
        value modulesToRefresh = modules.filter(IdeModule.isCeylonArchive).sequence();
        
        value ceylonArchivesRefreshingTicks = modulesToRefresh.size*10;
        
        try(progress = monitor.Progress(ceylonArchivesRefreshingTicks, "Refreshing Ceylon archives")) {
            progress.iterate(modulesToRefresh)
            (10, IdeModuleAlias.refresh);
        }
    }
    
    void typecheckDependencies(BaseProgressMonitor monitor) {
        assert(exists modules = ceylonProject.modules,
            exists typeChecker = ceylonProject.typechecker);
        
        value dependencyNumber = CeylonIterable(typeChecker.phasedUnitsOfDependencies)
                .fold(0)((number, pus) => number + pus.phasedUnits.size());
        value dependenciesTypecheckingTicks = dependencyNumber * 6;
        
        try(progress = monitor.Progress(dependenciesTypecheckingTicks, "Typechecking `` dependencyNumber `` dependencies fro project `` ceylonProject.name ``")) {
            
            value dependencies = CeylonIterable(typeChecker.phasedUnitsOfDependencies)
                    .flatMap((phasedUnits) => CeylonIterable(phasedUnits.phasedUnits))
                    .sequence();
            
            value dependenciesStep = typecheckingStep(dependencies, progress);
            {
                [PhasedUnit.scanDeclarations, "scanning declarations", 1],
                [PhasedUnit.scanTypeDeclarations, "scanning types", 2],
                [PhasedUnit.validateRefinement, "validating refinement", 1],
                [PhasedUnit.analyseTypes, "analysing types", 2]     // The Needed to have the right values in the Value.trans field (set in Expression visitor)
                // which in turn is important for debugging !
            }.each(unflatten(dependenciesStep));
        }
    }
    
    {ProjectPhasedUnitAlias*} updateUnits(Set<NativeFile> filesRequiringCeylonModelUpdate, BaseProgressMonitor monitor) {
        value fileNumber = filesRequiringCeylonModelUpdate.size;
        value sourceTypecheckingTicks = fileNumber * 10;
        value sourceUpdatingTicks = fileNumber * 5;
        try(progress = monitor.Progress(sourceTypecheckingTicks + sourceUpdatingTicks, "Updating `` fileNumber `` source files of project `` ceylonProject.name ``")) {
            assert(exists typeChecker=ceylonProject.typechecker,
                exists modules = ceylonProject.modules,
                exists modelLoader = ceylonProject.modelLoader);
            
            value cleanedPackages = HashSet<String>(unlinked);
            value phasedUnitsToUpdate = LinkedList<ProjectPhasedUnitAlias>();
            
            for (fileToUpdate in filesRequiringCeylonModelUpdate) {
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException();
                }
                
                value virtualFile = ceylonProject.getOrCreateFileVirtualFile(fileToUpdate);
                
                // skip non-ceylon files
                if(!ceylonProject.isCeylon(fileToUpdate)) {
                    if (ceylonProject.isJava(fileToUpdate)) {
                        if (is BaseJavaUnitAlias toRemove = virtualFile.unit) {
                            toRemove.remove();
                        } else {
                            if(exists packageName = virtualFile.ceylonPackage?.nameAsString,
                                ! cleanedPackages.contains(packageName)) {
                                modelLoader.clearCachesOnPackage(packageName);
                                cleanedPackages.add(packageName);
                            }
                        }
                    }
                    progress.worked(4);
                    continue;
                }
                
                value srcFolder = virtualFile.rootFolder;
                
                ProjectPhasedUnitAlias? alreadyBuiltPhasedUnit = 
                        unsafeCast<ProjectPhasedUnitAlias?>(
                    typeChecker.phasedUnits.getPhasedUnit(virtualFile));
                
                Package? pkg;
                if (exists alreadyBuiltPhasedUnit) {
                    // Editing an already built file
                    pkg = alreadyBuiltPhasedUnit.\ipackage;
                }
                else {
                    pkg = virtualFile.parent?.ceylonPackage;
                }
                if (! srcFolder exists || ! pkg exists) {
                    progress.worked(4);
                    continue;
                }
                assert(exists srcFolder,
                    exists pkg);
                
                value newPhasedUnit = 
                        ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile>(
                    ceylonProject, virtualFile, srcFolder)
                        .parseFileToPhasedUnit(modules.manager, typeChecker, virtualFile, srcFolder, pkg);
                phasedUnitsToUpdate.add(newPhasedUnit);
                progress.worked(4);
            }
            if (progress.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            if (phasedUnitsToUpdate.empty) {
                return {};
            }
            
            for (pu in phasedUnitsToUpdate) {
                pu.install();
                progress.worked(1);
            }
            
            modelLoader.setupSourceFileObjects(JavaList(phasedUnitsToUpdate));
        }
        return {};        
    }
    
    void initializeLanguageModule(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Loading language module packages for project `` ceylonProject.name ``")) {
            assert(exists loader = ceylonProject.modelLoader);
            value languageModule = loader.languageModule;
            loader.loadPackage(languageModule, "com.redhat.ceylon.compiler.java.metadata", true);
            progress.worked(250);
            loader.loadPackage(languageModule, Module.\iLANGUAGE_MODULE_NAME, true);
            progress.worked(250);
            loader.loadPackage(languageModule, "ceylon.language.descriptor", true);
            progress.worked(250);
            loader.loadPackageDescriptors();
            progress.worked(250);
        }
    }
    
    shared void updateCeylonModel(BaseProgressMonitor monitor) => 
            synchronize(this, () {
        withCeylonModelCaching(() {
            ceylonProject.withSourceModel(false, void () {
                try(progress = monitor.Progress(1000, "Updating the Ceylon model of project `` ceylonProject.name ``")) {
                    value filesRequiringCeylonModelUpdate = state.ceylonModelUpdateRequired.clear();
                    {ProjectPhasedUnitAlias*} phasedUnitsToTypecheck;
                    if (state.buildType.fullBuildPlanned) {
                        // Full Build
                        
                        phasedUnitsToTypecheck = ceylonProject.parsedUnits;
                        
                        // First typecheck PhasedUnits of dependencies (source archives)
                        typecheckDependencies(progress.newChild(100));
                        
                        // Secondly initialize the language module
                        initializeLanguageModule(progress.newChild(100));
                    } else {
                        // Incremental Build
                        
                        // First refresh the modules that are cross-project references to sources modules
                        // in referenced projects. This will :
                        // - clean the binary declarations and reload the class-to-source mapping file for binary-based modules,
                        // - remove old PhasedUnits and parse new or updated PhasedUnits from the source archive for source-based modules
                        refreshCeylonArchives(progress.newChild(50));
                        
                        // Secondly typecheck again the changed PhasedUnits in changed external source modules
                        // (those which come from referenced projects)
                        typecheckDependencies(progress.newChild(50));
                        
                        // Then update the units (clean Java units and replace Ceylon PhasedUnits)
                        phasedUnitsToTypecheck = updateUnits(filesRequiringCeylonModelUpdate, progress.newChild(100));
                    }
                    // Finally typecheck the project sources, manage the related errors, and collection dependencies
                    progress.updateRemainingWork(800);
                    typecheck(progress.newChild(800), phasedUnitsToTypecheck);
                    state.buildType.resetFullBuild();
                }
            });
        });
    });
    
    shared void performBinaryGeneration(BaseProgressMonitor monitor) =>
            synchronize(this, () {
        withCeylonModelCaching(() {
            try(progress = monitor.Progress(1000, "Binary Generation of project `` ceylonProject.name ``")) {
                
            }
        });
    });
    
    shared void consumeModelChanges(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Calculating dependencies on project `` ceylonProject.name ``")) {
            if (state.buildType.fullBuildPlanned) {
                value projectNativeFiles = ceylonProject.projectNativeFiles.sequence();
                state.ceylonModelUpdateRequired.reset(projectNativeFiles);
                state.jvmBackendGenerationRequired.reset(projectNativeFiles);
            } else {
                // calculate dependencies
                // clean removed things
                // Remember cleaning the errors / tasks on the remove files
            }
        }
    }
    
    // TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
    // TODO :  A la fin : flusher le buildState + erreurs  sur le disque
    // TODO : Au démmarrage si le build state n'est pas présent => full build.
}