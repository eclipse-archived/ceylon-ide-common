import ceylon.collection {
    HashSet,
    unlinked,
    LinkedList,
    ArrayList
}
import ceylon.interop.java {
    synchronize,
    CeylonIterable,
    JavaList,
    javaClass,
    JavaIterable,
    JavaCollection
}

import com.redhat.ceylon.cmr.api {
    SourceStream
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.redhat.ceylon.cmr.impl {
    ShaSigner
}
import com.redhat.ceylon.common {
    Backend,
    FileUtil
}
import com.redhat.ceylon.compiler.java.loader {
    UnknownTypeCollector
}
import com.redhat.ceylon.compiler.java.util {
    Util
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    Warning
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message
}
import com.redhat.ceylon.compiler.typechecker.util {
    WarningSuppressionVisitor
}
import com.redhat.ceylon.ide.common.model.parsing {
    ProjectSourceParser
}
import com.redhat.ceylon.ide.common.platform {
    VfsServicesConsumer,
    platformUtils,
    Status
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    ImmutableMapWrapper,
    ImmutableSetWrapper,
    Path,
    BaseProgressMonitor,
    unsafeCast,
    ErrorVisitor,
    equalsWithNulls,
    toCeylonStringIterable,
    CarUtils
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Module,
    Cancellable,
    Declaration,
    Unit
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    File,
    IOException
}
import java.util {
    JSet=Set,
    Properties
}

import net.lingala.zip4j.core {
    ZipFile
}
import net.lingala.zip4j.exception {
    ZipException
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

"We don't want to run the *Did you mean ?* search during the typechecking in the IDE:
 Since we already have quick fixes that do even better, it's just useless processing."
shared Cancellable cancelDidYouMeanSearch => Cancellable.alwaysCancelled;


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
    
    shared CeylonProjectAlias ceylonProject;
    
    shared class State() {
        "Unanalyzed changes added since the last time [[analyzeChanges]] was called.
         The list is filled by [[fileTreeChanged]] and flushed for use by [[analyzeChanges]]"
        shared ImmutableSetWrapper<ChangeToAnalyze> fileChangesToAnalyze = ImmutableSetWrapper<ChangeToAnalyze>();
        
        "Model changes since the last time [[consumeModelChanges]] was called.
         The list is filled by [[analyzeChanges]] and flushed for use by [[consumeModelChanges]]"
        shared ImmutableSetWrapper<FileVirtualFileChange> modelFileChanges = ImmutableSetWrapper<FileVirtualFileChange>();
        
        "Sources requiring a typechecking during the next [[updateCeylonModel]] call.
         The list is filled by [[consumeModelChanges]] and flushed for use by [[updateCeylonModel]]"
        shared ImmutableSetWrapper<FileVirtualFileAlias> ceylonModelUpdateRequired = ImmutableSetWrapper<FileVirtualFileAlias>();
        
        "Sources requiring a JVM binary generation during the next [[performBinaryGeneration]] call.
         The list is filled by [[consumeModelChanges]] and flushed for use by [[performBinaryGeneration]]"
        shared ImmutableSetWrapper<FileVirtualFileAlias> jvmBackendGenerationRequired = ImmutableSetWrapper<FileVirtualFileAlias>();
        
        shared ImmutableSetWrapper<SourceFileMessage> backendMessages = ImmutableSetWrapper<SourceFileMessage>();
        shared ImmutableSetWrapper<SourceFileMessage> frontendMessages = ImmutableSetWrapper<SourceFileMessage>();
        shared ImmutableSetWrapper<ProjectMessage> projectMessages = ImmutableSetWrapper<ProjectMessage>();
        
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
            
            shared Boolean fullBuildRequested =>
                    _fullBuildRequested;
            
            shared Boolean classpathResolutionRequested =>
                    _classpathResolutionRequested;
            
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
    
    shared abstract class BuildMessage() 
            of ProjectMessage | SourceFileMessage {
        shared formal String message;
        shared formal Backend? backend;
        shared formal Severity severity;
        
        shared actual formal Boolean equals(Object that);
    }
    
    shared abstract class ProjectMessage(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            of ProjectWarning | ProjectError
            extends BuildMessage() {
        shared NativeProject project = theProject;
        message => theMessage;
        backend => theBackend;
        
        shared actual Boolean equals(Object that) {
            if (is ProjectMessage that) {
                return message==that.message && 
                        equalsWithNulls(backend,that.backend) && 
                        severity==that.severity && 
                        project==that.project;
            }
            else {
                return false;
            }
        }
        
        shared actual Integer hash {
            variable value hash = 1;
            hash = 31*hash + message.hash;
            hash = 31*hash + project.hash;
            hash = 31*hash + severity.hash;
            hash = 31*hash + (backend?.hash else 0);
            return hash;
        }
    }
    
    shared class ProjectError(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            extends ProjectMessage(theMessage, theProject, theBackend) {
        severity = Severity.error;
    }
    
    shared class ProjectWarning(
        String theMessage,
        NativeProject theProject,
        Backend theBackend=Backend.\iHeader)
            extends ProjectMessage(theMessage, theProject, theBackend) {
        severity = Severity.warning;
    }
    
    shared abstract class SourceFileMessage (
        NativeFile theFile,
        Integer theStartOffset,
        Integer theEndOffset,
        Integer theStartCol,
        Integer theStartLine,
        Message theTypecheckerMessage) 
            of SourceFileWarning | SourceFileError
            extends BuildMessage() {
        shared NativeFile file = theFile;
        shared Message typecheckerMessage = theTypecheckerMessage;
        shared Integer startLine = theStartLine;
        shared Integer startCol = theStartCol;
        shared Integer startOffset = theStartOffset;
        shared Integer endOffset = theEndOffset;
        
        message => typecheckerMessage.message;
        backend => typecheckerMessage.backend;
        
        shared actual Boolean equals(Object that) {
            if (is SourceFileMessage that) {
                return message==that.message && 
                        theStartOffset==that.theStartOffset &&
                        equalsWithNulls(backend, that.backend) && 
                        severity==that.severity && 
                        file==that.file;
            }
            else {
                return false;
            }
        }
        
        shared actual Integer hash {
            variable value hash = 1;
            hash = 31*hash + message.hash;
            hash = 31*hash + file.hash;
            hash = 31*hash + severity.hash;
            hash = 31*hash + (backend?.hash else 0);
            hash = 31*hash + theStartOffset;
            return hash;
        }
    }
    
    shared class SourceFileError(
        NativeFile theFile,
        Integer theStartOffset,
        Integer theEndOffset,
        Integer theStartCol,
        Integer theStartLine,
        Message theTypecheckerMessage)
            extends SourceFileMessage(
                theFile, 
                theStartOffset,
                theEndOffset,
                theStartCol,
                theStartLine,
                theTypecheckerMessage) {
        severity = Severity.error;
    }
    
    shared class SourceFileWarning(
        NativeFile theFile,
        Integer theStartOffset,
        Integer theEndOffset,
        Integer theStartCol,
        Integer theStartLine,
        Message theTypecheckerMessage)
            extends SourceFileMessage(
                theFile, 
                theStartOffset,
                theEndOffset,
                theStartCol,
                theStartLine,
                theTypecheckerMessage) {
        severity = Severity.warning;
    }
    
    shared Set<SourceFileMessage> backendMessages => state.backendMessages.immutable;
    shared Set<SourceFileMessage> frontendMessages => state.frontendMessages.immutable;
    shared {SourceFileMessage*} sourceFileMessages => state.frontendMessages.immutable.chain(state.backendMessages.immutable);
    shared Set<ProjectMessage> projectMessages => state.projectMessages.immutable;
    shared {BuildMessage*} messages => sourceFileMessages.chain(state.projectMessages.immutable);
    
    shared {SourceFileMessage*} messagesForSourceFile(NativeFile file) => 
            sourceFileMessages.filter((error) => error.file == file);
    
    shared Boolean sourceFileHasMessages(NativeFile file, Boolean searchedSeverity(Severity severity) => true) =>
          messagesForSourceFile(file)
            .any((message) => searchedSeverity(message.severity));
    
    shared Map<NativeFile,Set<String>> missingClasses => state.missingClasses.immutable;
    
    shared {ChangeToAnalyze*} fileChangesToAnalyze => state.fileChangesToAnalyze.immutable;
    
    shared Boolean somethingToDo => 
            state.buildType.fullBuildRequested 
            || state.buildType.classpathResolutionRequested
            || ! state.fileChangesToAnalyze.empty;
    
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
                        if (exists relativePath = vfsServices.getProjectRelativePath(resource, changeProject),
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
                                    ! sourceFileHasMessages(file.nativeResource, Severity.error.equals),
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
            
            state.modelFileChanges.addAll(changesToAnalyze.narrow<FileVirtualFileChange>());
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
    
    shared void fileTreeChanged({<[NativeResourceChange, NativeProject]|ResourceVirtualFileChange>*} changes) {
        state.fileChangesToAnalyze.addAll(changes); 
    }
    
    void initializeTheCeylonModel(BaseProgressMonitor monitor) => 
            withCeylonModelCaching {
                void do() {
                    ceylonProject.withSourceModel(false, void () {
                        try(progress = monitor.Progress(1000, "Initializing the Ceylon model for project `` ceylonProject.name ``")) {
                            typecheckDependencies(progress.newChild(300));
                            initializeLanguageModule(progress.newChild(50));
                            typecheck(progress.newChild(650), ceylonProject.parsedUnits);
                        }
                    }, 20);
                }
            };
    
    void resolveClasspath(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Ceylon build of project `` ceylonProject.name ``")) {
            ceylonProject.buildHooks.each((hook) => hook.beforeClasspathResolution(this, state));
            ceylonProject.parseCeylonModel(progress.newChild(100));
            ceylonProject.buildHooks.each((hook) => hook.afterClasspathResolution(this, state));
            state.buildType.resetClasspathResolution();
        }
    }
    
    shared Boolean performBuild(BaseProgressMonitor monitor, Boolean includeBinaryGeneration=false) {
        variable Boolean finished = false;
        try(progress = monitor.Progress(1000, "Ceylon build of project `` ceylonProject.name ``")) {
            // should do pre-build checks
            if (!analyzeChanges(progress.newChild(100))) {
                return false;
            }
            
            if (state.buildType.classpathResolutionPlanned || state.buildType.fullBuildPlanned) {
                resolveClasspath(progress.newChild(100));
            }
            
            progress.updateRemainingWork(800);
            
            if (! state.buildType.fullBuildPlanned && 
                ! ceylonProject.typechecked) {
                // Do a full typecheck to populate the Ceylon model.
                initializeTheCeylonModel(progress.newChild(200));
            }
            
            progress.updateRemainingWork(600);
            
            consumeModelChanges(progress.newChild(100));
            
            if (state.ceylonModelUpdateRequired.empty &&
                (!includeBinaryGeneration || state.jvmBackendGenerationRequired.empty))  {
                finished = true;
                return true;
            }
            
            updateCeylonModel(progress.newChild(300));
            
            performBinaryGeneration(progress.newChild(200));
            finished = true;
        } finally {
            if (!finished) {
                state.buildType.requestFullBuild();
                state.buildType.requestClasspathResolution();
            }
        }
        return finished;
    }
    
    void applyTypecheckingPhase({PhasedUnit*} phasedUnits, BaseProgressMonitor.Progress progress)(String subTaskPrefix, Integer ticks, void phase(PhasedUnit pu)) {
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
        try(progress = monitor.Progress(numberOfPhasedUnits * 10, "Typechecking `` numberOfPhasedUnits `` source files of project `` ceylonProject.name ``")) {
            value files = phasedUnitsToTypecheck.map((pu) => pu.resourceFile).sequence();
            // remove the non-backend project errors
            state.projectMessages.clear();
            // remove the non-backend errors on the files corresponding to 
            state.frontendMessages.removeEvery((error) => error.file in files);
            
            // TODO : remove tasks (we should first define tasks in the build state...)
            
            // Typecheck the main phases on the given phased units 
            //    (apart from the tree validation and the module / package descriptors)
            
            value utc = UnknownTypeCollector();
            
            value mainTypecheckingPhases = {
                ["scanning declarations", 1, void(PhasedUnit pu) => pu.scanDeclarations()],
                ["scanning types", 2, void(PhasedUnit pu) => pu.scanTypeDeclarations(cancelDidYouMeanSearch)],
                ["validating refinement", 1, void(PhasedUnit pu) => pu.validateRefinement()],
                ["analysing usages", 3, void(PhasedUnit pu) { 
                    pu.analyseTypes(cancelDidYouMeanSearch);
                    if (ceylonProject.showWarnings) {
                        pu.analyseUsage();
                    }
                }],
                ["analyzing flow", 1, void(PhasedUnit pu) => pu.analyseFlow()],
                ["collecting unknown types", 1, void(PhasedUnit pu) => pu.compilationUnit.visit(utc)]
            };
            
            mainTypecheckingPhases.each(unflatten(
                applyTypecheckingPhase(phasedUnitsToTypecheck, progress)));
            
            if (progress.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }

            // Collect dependencies
            progress.subTask("Collecting dependencies for project: `` ceylonProject.name ``");

            for (pu in phasedUnitsToTypecheck) {
                UnitDependencyVisitor(pu).visit(pu.compilationUnit);
                progress.worked(1);
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException();
                }
            }
            
            // add problems
            progress.worked(1);
            if (progress.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            
            
            progress.subTask("Collecting problems for project: `` ceylonProject.name ``");

            function retrieveErrors(TypecheckerAliases<NativeProject,NativeResource,NativeFolder,NativeFile>.ProjectPhasedUnitAlias projectPhasedUnit) {
                value compilationUnit = projectPhasedUnit.compilationUnit;
                compilationUnit.visit(WarningSuppressionVisitor<Warning>(javaClass<Warning>(),
                    ceylonProject.configuration.suppressWarningsEnum));
                value messages = LinkedList<SourceFileMessage>();
                compilationUnit.visit(object extends ErrorVisitor() {
                    shared actual void handleMessage(Integer startOffset, Integer endOffset,
                        Integer startCol, Integer startLine, Message message) {
                        
                        value createError = if (message.warning)
                        then SourceFileWarning
                        else SourceFileError;
                        
                        messages.add(
                            createError(projectPhasedUnit.resourceFile, startOffset, endOffset, startCol, startLine, message)); 
                    }
                });
                
                return messages;
            }
            
            state.frontendMessages.addAll(
                expand(phasedUnitsToTypecheck
                    .map(retrieveErrors)));
            
            ceylonProject.model.buildMessagesChanged(ceylonProject, frontendMessages, null, null);
            // TODO addTaskMarkers(file, phasedUnit.getTokens());
        }
    }
    
    void refreshCeylonArchives(BaseProgressMonitor monitor) {
        assert(exists modules = ceylonProject.modules,
            exists typeChecker = ceylonProject.typechecker);
        value modulesToRefresh = modules.filter(IdeModule.isCeylonArchive).sequence();
        
        value ceylonArchivesRefreshingTicks = modulesToRefresh.size*10;
        
        try(progress = monitor.Progress(ceylonArchivesRefreshingTicks, "Refreshing Ceylon archives")) {
            progress.iterate {
                work = 10;
                on(IdeModuleAlias m) => m.refresh();
            }(modulesToRefresh);
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
            
            value dependencyTypecheckingPhases = {
                ["scanning declarations", 1, void (PhasedUnit pu) => pu.scanDeclarations()],
                ["scanning types", 2, void (PhasedUnit pu) => pu.scanTypeDeclarations(cancelDidYouMeanSearch)],
                ["validating refinement", 1, void (PhasedUnit pu) => pu.validateRefinement()],
                ["analysing types", 2, void (PhasedUnit pu) => pu.analyseTypes(cancelDidYouMeanSearch)]     // The Needed to have the right values in the Value.trans field (set in Expression visitor)
                // which in turn is important for debugging !
            };
            
            dependencyTypecheckingPhases.each(unflatten(
                applyTypecheckingPhase(dependencies, progress)));
        }
    }
    
    {ProjectPhasedUnitAlias*} updateUnits(Set<FileVirtualFileAlias> filesRequiringCeylonModelUpdate, BaseProgressMonitor monitor) {
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
                
                // skip non-ceylon files
                if(!ceylonProject.isCeylon(fileToUpdate.nativeResource)) {
                    if (ceylonProject.isJava(fileToUpdate.nativeResource)) {
                        if (is JavaUnitAlias toUpdate = fileToUpdate.unit) {
                            toUpdate.update();
                        } else {
                            if(exists packageName = fileToUpdate.ceylonPackage?.nameAsString,
                                ! cleanedPackages.contains(packageName)) {
                                modelLoader.clearCachesOnPackage(packageName);
                                cleanedPackages.add(packageName);
                            }
                        }
                    }
                    progress.worked(4);
                    continue;
                }
                
                value srcFolder = fileToUpdate.rootFolder;
                
                ProjectPhasedUnitAlias? alreadyBuiltPhasedUnit = 
                        unsafeCast<ProjectPhasedUnitAlias?>(
                    typeChecker.phasedUnits.getPhasedUnit(fileToUpdate));
                
                Package? pkg;
                if (exists alreadyBuiltPhasedUnit) {
                    // Editing an already built file
                    pkg = alreadyBuiltPhasedUnit.\ipackage;
                }
                else {
                    pkg = fileToUpdate.parent?.ceylonPackage;
                }
                if (! srcFolder exists || ! pkg exists) {
                    progress.worked(4);
                    continue;
                }
                assert(exists srcFolder,
                    exists pkg);
                
                value newPhasedUnit = 
                        ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile>(
                    ceylonProject, fileToUpdate, srcFolder)
                        .parseFileToPhasedUnit(modules.manager, typeChecker, fileToUpdate, srcFolder, pkg);
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
            
            if (progress.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            
            value incrementalTypecheckingPreliminaryPhases = {
                ["validating tree", 1, void(PhasedUnit pu) => pu.validateTree()],
                ["module descriptor parsing", 1, void(PhasedUnit pu) { pu.visitSrcModulePhase(); }], // The use of the specifier is prohibited here, 
                                                                                                      // because visitSrcModulePhase() would seen as returning 
                                                                                                      // Module though in fact can return null (Java method).
                ["module and package descriptor completion", 1, void(PhasedUnit pu) => pu.visitRemainingModulePhase()]
            };
            
            incrementalTypecheckingPreliminaryPhases.each(unflatten(
                applyTypecheckingPhase(phasedUnitsToUpdate, progress)));
            return phasedUnitsToUpdate;        
        }
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
    
    class VirtualFileSourceStream(FileVirtualFileAlias virtualFile) 
            extends SourceStream() {
        inputStream => virtualFile.inputStream;
        sourceRelativePath => virtualFile.rootRelativePath?.string else "<unknown>";
    }
     
    Boolean updateSourceArchives(BaseProgressMonitor monitor, {FileVirtualFileAlias*} updatedFiles) {
        assert(exists sourceModules = ceylonProject.modules?.filter(BaseIdeModule.isProjectModule)?.sequence());
        variable value success = true;
        try(progress = monitor.Progress(sourceModules.size, "Generating source archives")) {
            value cmrLogger = platformUtils.cmrLogger;
            value outRepo = CeylonUtils.repoManager()
                    .offline(ceylonProject.configuration.offline)
                    .cwd(ceylonProject.rootDirectory)
                    .outRepo(ceylonProject.ceylonModulesOutputDirectory.absolutePath)
                    .logger(cmrLogger)
                    .buildOutputManager();
            for (m in sourceModules) {
                try {
                    value sourceDirectories = ceylonProject.sourceFolders.map(
                            (virtualFolder) => virtualFolder.toJavaFile).coalesced;
                    value sac = CeylonUtils.makeSourceArtifactCreator(outRepo, JavaIterable(sourceDirectories),
                        m.nameAsString, m.version, false, cmrLogger);
                    sac.copyStreams(JavaCollection<SourceStream>(updatedFiles
                        .filter((file)
                            => file.sourceFile &&
                                equalsWithNulls(file.ceylonModule, m))
                        .map(VirtualFileSourceStream).coalesced.sequence()));
                } catch (IOException e) {
                    platformUtils.log(Status._ERROR, "Source generation failed for module ``m``", e);
                    success = false;
                }
                progress.worked(1);
            }
        }
        return success;
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
                        
                        ceylonProject.state = ProjectState.typechecking;

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
                    progress.updateRemainingWork(700);
                    typecheck(progress.newChild(700), phasedUnitsToTypecheck);
                    state.buildType.resetFullBuild();
                    ceylonProject.state = ProjectState.typechecked;
                    if (! updateSourceArchives(progress.newChild(100), filesRequiringCeylonModelUpdate)) {
                        requestFullBuild();
                    }
                }
            });
        });
    });
    
    shared void performBinaryGeneration(BaseProgressMonitor monitor) =>
            synchronize(this, () {
        withCeylonModelCaching(() {
            try(progress = monitor.Progress(1000, "Binary Generation of project `` ceylonProject.name ``")) {
                state.backendMessages.clear();
                state.missingClasses.clear();
                // TODO: implement binary generation.
            }
        });
    });
    
    void cleanRemovedFilesFromCeylonModel([FileVirtualFileAlias*] filesRemovedFromCurrentProject) {
        for (file in filesRemovedFromCurrentProject) {
            if(ceylonProject.isCeylon(file.nativeResource)) {
                // Remove the ceylon phasedUnit (which will also remove the unit from the package)
                if (exists phasedUnitToDelete = ceylonProject.getParsedUnit(file)) {
                    phasedUnitToDelete.remove();
                }
            }
            else if (ceylonProject.isJava(file.nativeResource)) {
                // Remove the external unit from the package
                if (exists pkg = file.ceylonPackage) {
                    for (Unit unitToTest in pkg.units) {
                        if (unitToTest.filename == file.name) {
                            assert(is JavaUnitAlias javaUnit = unitToTest);
                            javaUnit.remove();
                            break;
                        }
                    }
                }
            }
        }
        
    }
    
    void cleanRemovedFilesFromOutputs([FileVirtualFileAlias*] filesRemovedFromCurrentProject) {
        if (! nonempty filesRemovedFromCurrentProject) {
            return;
        }
        
        value typeChecker = ceylonProject.typechecker;
        if (!exists typeChecker) {
            return;
        }
        
        value moduleJars = HashSet<File>();
        
        for (file in filesRemovedFromCurrentProject) {
            if (exists pkg = file.ceylonPackage,
                exists relativeFilePath = file.rootRelativePath?.string) {

                Module m = pkg.\imodule;
                value modulesOutputDirectory = ceylonProject.ceylonModulesOutputDirectory;

                Boolean explodeModules = false; // TODO : Part of what will be added in the next step
                File? getCeylonClassesOutputDirectory(BaseCeylonProject p) => null; // TODO : Part of what will be added in the next step

                value ceylonOutputDirectory = if (explodeModules) then 
                getCeylonClassesOutputDirectory(ceylonProject) else null;
                
                File moduleDir = Util.getModulePath(modulesOutputDirectory, m);
                
                Boolean fileIsResource = file.resourceFile;
                Boolean fileIsSource = file.sourceFile;
                
                //Remove the classes belonging to the source file from the
                //module archive and from the JDTClasses directory
                File moduleJar = File(moduleDir, Util.getModuleArchiveName(m));
                if(moduleJar.\iexists()){
                    moduleJars.add(moduleJar);
                    try {
                        value entriesToDelete = ArrayList<String>();
                        value zipFile = ZipFile(moduleJar);
                        
                        Properties mapping = CarUtils.retrieveMappingFile(zipFile);
                        
                        if (fileIsResource) {
                            entriesToDelete.add(relativeFilePath);
                        } else {
                            for (className in toCeylonStringIterable(mapping.stringPropertyNames())) {
                                String? sourceFile = mapping.getProperty(className);
                                if (equalsWithNulls(relativeFilePath, sourceFile)) {
                                    entriesToDelete.add(className);
                                }
                            }
                        }
                        
                        for (entryToDelete in entriesToDelete) {
                            try {
                                zipFile.removeFile(entryToDelete);
                            } catch (ZipException e) {
                            }
                            
                            if (explodeModules) {
                               File(ceylonOutputDirectory, 
                                    entryToDelete.replace("/", File.separator))
                                        .delete();
                            }
                        }
                    } catch (ZipException e) {
                        e.printStackTrace();
                    }
                }
                
                if (fileIsSource) {
                    //Remove the source file from the source archive
                    File moduleSrc = File(moduleDir, Util.getSourceArchiveName(m));
                    if(moduleSrc.\iexists()){
                        moduleJars.add(moduleSrc);
                        try {
                            value zipFile = ZipFile(moduleSrc);
                            if(exists fileHeader = zipFile.getFileHeader(relativeFilePath)){
                                zipFile.removeFile(fileHeader);
                            }
                        } catch (ZipException e) {
                            e.printStackTrace();
                        }
                    }
                }
                
                if (fileIsResource) {
                    File resourceFile = File(
                        moduleDir, 
                        "module-resources" + File.separator + relativeFilePath.replace("/", File.separator));
                    resourceFile.delete();
                }

                
            }
        }
        
        for (moduleJar in moduleJars) {
            ShaSigner.sign(moduleJar, platformUtils.cmrLogger, false);
        }
    }
    
    suppressWarnings("unusedDeclaration")
    void cleanChangedFilesFromExplodedDirectory(Set<FileVirtualFileChange> changedFiles) {
        // TODO implement this and call it when adding support for exploded directories
    } 
    
    shared void consumeModelChanges(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Calculating dependencies on project `` ceylonProject.name ``")) {
            value changedFiles = state.modelFileChanges.clear();
            if (state.buildType.fullBuildPlanned) {
                value projectNativeFiles = ceylonProject.projectFiles.sequence();
                state.ceylonModelUpdateRequired.reset(projectNativeFiles);
                state.jvmBackendGenerationRequired.reset(projectNativeFiles);
            } else {
                // calculate dependencies
                calculateDependencies(changedFiles, progress.newChild(900));
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException();
                }

                value filesRemovedFromCurrentProject = changedFiles
                        .filter((change) => change.type == ResourceChangeType.fileRemoval)
                        .map((change) => unsafeCast<FileVirtualFileRemoval>(change).resource)
                        .filter((file) => equalsWithNulls(file.ceylonProject, ceylonProject))
                        .sequence();

                progress.subTask("Cleaning files and markers for project `` ceylonProject.name ``");
                cleanRemovedFilesFromCeylonModel(filesRemovedFromCurrentProject);
                progress.worked(40);
                cleanRemovedFilesFromOutputs(filesRemovedFromCurrentProject);
                progress.worked(40);
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException();
                }

                for(removedFile in filesRemovedFromCurrentProject) {
                    state.frontendMessages.removeEvery((message) => message.file == removedFile);
                    state.backendMessages.removeEvery((message) => message.file == removedFile);
                    state.missingClasses.remove(removedFile.nativeResource);
                }
                
                // Remember also cleaning the tasks on the remove files
            }
        }
    }

    void calculateDependencies(Set<FileVirtualFileChange> changedFiles, Cancellable cancellable) {
        
        value astAwareIncrementalBuild = true;
        
        value filesToAddInTypecheck = HashSet<FileVirtualFileAlias>();
        value filesToAddInCompile = HashSet<FileVirtualFileAlias>();
        
        if (!changedFiles.empty) {
            Set<FileVirtualFileAlias> allTransitivelyDependingFiles = searchForDependantFiles(changedFiles, false, true, cancellable);
            Set<FileVirtualFileAlias> directlyDependingFiles = searchForDependantFiles(changedFiles, astAwareIncrementalBuild, false, cancellable);
            
            if (cancellable.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            
            for (phasedUnit in ceylonProject.parsedUnits) {
                value unit = phasedUnit.unit;
                if (unit.unresolvedReferences) {
                    value fileToAdd = phasedUnit.unitFile;
                    if (fileToAdd.existsOnDisk) {
                        filesToAddInTypecheck.add(fileToAdd);
                        filesToAddInCompile.add(fileToAdd);
                    }
                }
                JSet<Declaration> duplicateDeclarations = unit.duplicateDeclarations;
                if (!duplicateDeclarations.empty) {
                    value fileToAdd = phasedUnit.unitFile;
                    if (fileToAdd.existsOnDisk) {
                        filesToAddInTypecheck.add(fileToAdd);
                        filesToAddInCompile.add(fileToAdd);
                    }
                    for (duplicateDeclaration in duplicateDeclarations) {
                        Unit duplicateUnit = duplicateDeclaration.unit;
                        if (is SourceFile 
                            & IResourceAware<NativeProject, NativeFolder, NativeFile> duplicateUnit,
                            exists duplicateDeclFile = duplicateUnit.resourceFile,
                            exists duplicateDeclVirtualFile = 
                                    ceylonProject.model.getProject(duplicateUnit.resourceProject)
                                    ?.getOrCreateFileVirtualFile(duplicateDeclFile),
                            duplicateDeclVirtualFile.existsOnDisk) {
                            filesToAddInTypecheck.add(duplicateDeclVirtualFile);
                            filesToAddInCompile.add(duplicateDeclVirtualFile);
                        }
                    }
                }
            }
            
            if (cancellable.cancelled) {
                throw platformUtils.newOperationCanceledException();
            }
            
            for (f in allTransitivelyDependingFiles) {
                if (equalsWithNulls(f.ceylonProject, ceylonProject)) {
                    if (f.sourceFile || f.resourceFile) {
                        if (f.existsOnDisk) {
                            filesToAddInTypecheck.add(f);
                            if (!astAwareIncrementalBuild || 
                                f in directlyDependingFiles || 
                                    ceylonProject.isJava(f.nativeResource)) {
                                filesToAddInCompile.add(f);
                            }
                        }
                        else {
                            // If the file is moved : add a dependency on the new file
                            value change = changedFiles.find((change) => change.resource == f);
                            if (is FileVirtualFileRemoval change,
                                exists movedFile = change.movedTo) {
                                if (movedFile.sourceFile || movedFile.resourceFile) {
                                    filesToAddInTypecheck.add(movedFile);
                                    if (!astAwareIncrementalBuild || directlyDependingFiles.contains(movedFile)) {
                                        filesToAddInCompile.add(movedFile);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        value filesWithBackendError = backendMessages
                .filter((message) => message.severity == Severity.error)
                .map((message) => ceylonProject.getOrCreateFileVirtualFile(message.file));

        value filesWithMissingClassFile = missingClasses.keys
                .map((nativeFile) => ceylonProject.getOrCreateFileVirtualFile(nativeFile));
                
        for (file in filesWithBackendError
                        .chain(filesWithMissingClassFile)) {
            filesToAddInTypecheck.add(file);
            filesToAddInCompile.add(file);
        }
        
        state.ceylonModelUpdateRequired.addAll(filesToAddInTypecheck);
        state.jvmBackendGenerationRequired.addAll(filesToAddInCompile);
    }

    
    {String*} getDependentsOf(FileVirtualFileAlias srcFile,
        TypeChecker currentFileTypeChecker) {
        
        if (ceylonProject.isCeylon(srcFile.nativeResource),
            exists phasedUnit = 
                        currentFileTypeChecker.phasedUnits
                            .getPhasedUnit(srcFile),
            exists unit = phasedUnit.unit) {
            
            return toCeylonStringIterable(unit.dependentsOf);
        } 
        else {
            if (is JavaCompilationUnitAlias unit = srcFile.unit) {
                return toCeylonStringIterable(unit.dependentsOf);
            }
        }
        
        return {};
    }
    
    
    Set<FileVirtualFileAlias> searchForDependantFiles(Set<FileVirtualFileChange> changedFiles, Boolean filterAccordingToStructureDelta, Boolean includeTransitiveDependencies,  Cancellable cancellable) {
        value analyzedFiles= HashSet<FileVirtualFileAlias>();

        function shouldConsiderFile(FileVirtualFileAlias srcFile) {
            value alreadyAnalyzed = srcFile in analyzedFiles;
            analyzedFiles.add(srcFile);
            if (alreadyAnalyzed) {
                return false;
            }
            if (! srcFile.sourceFile) {
                // Don't search dependencies inside resource folders.
                return false;
            }
            if (filterAccordingToStructureDelta) {
                if (is ProjectSourceFileAlias projectSourceFile = srcFile.unit) {
                    if (! projectSourceFile.dependentsOf.empty) {
                        if (exists delta = projectSourceFile.buildDeltaAgainstModel(), 
                            delta.changes.empty,
                            delta.childrenDeltas.empty) {
                            return false;
                        }
                    }
                }
            }
            return true;
        }
        
        FileVirtualFileAlias? dependencyToFile(String dependingFilePath, CeylonProjectAlias currentFileCeylonProject) {
            value pathRelativeToProject = Path(dependingFilePath);
            if (is NativeFile depFile = vfsServices.findChild(ceylonProject.ideArtifact, pathRelativeToProject),
                ! vfsServices.isFolder(depFile)) {
                return ceylonProject.getOrCreateFileVirtualFile(depFile);
            } else if (is NativeFile depFile = vfsServices.findChild(currentFileCeylonProject.ideArtifact, pathRelativeToProject),
                ! vfsServices.isFolder(depFile)) {
                return ceylonProject.getOrCreateFileVirtualFile(depFile);
            } else {
                platformUtils.log(Status._WARNING, "could not resolve dependent unit: `` dependingFilePath ``");
                return null;
            }
        }

        value changeDependents= HashSet<FileVirtualFileAlias>();
        changeDependents.addAll(changedFiles*.resource);
        
        function searchForNewDependencies() => { 
            for (srcFile in changeDependents) 
                if (shouldConsiderFile(srcFile),
                    exists currentFileCeylonProject = srcFile.ceylonProject,
                    exists currentFileTypeChecker = currentFileCeylonProject.typechecker)
                    for (dependingFilePath in getDependentsOf(srcFile, currentFileTypeChecker))
                        if (exists depFile = dependencyToFile(dependingFilePath, currentFileCeylonProject))
                            depFile
        }.sequence();
        
        while(nonempty newDependencies = searchForNewDependencies()) {
            changeDependents.addAll(newDependencies);
            if (!includeTransitiveDependencies) {
                break;
            }
        }
        return changeDependents;
    }
    
    string => "Ceylon Build for project `` ceylonProject ``";
    
    // TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
    // TODO :  A la fin : flusher le buildState + erreurs  sur le disque
    // TODO : Au démmarrage si le build state n'est pas présent => full build.
}