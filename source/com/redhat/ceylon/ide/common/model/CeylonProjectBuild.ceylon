import com.redhat.ceylon.common {
    Backend,
    FileUtil
}
import com.redhat.ceylon.ide.common.platform {
    VfsServicesConsumer
}
import com.redhat.ceylon.ide.common.util {
    ImmutableMapWrapper,
    ImmutableSetWrapper,
    Path,
    BaseProgressMonitor
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
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
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    CeylonProjectAlias ceylonProject;

    shared class State() {
        shared variable Boolean fullBuildRequired = true;
        shared variable Boolean classpathResolutionRequired = true;
        
        "Sources requiring a typechecking during the next [[performTypechecking]] call"
        shared ImmutableSetWrapper<NativeFile> typecheckingRequired = ImmutableSetWrapper<NativeFile>();
        
        "Sources requiring a JVM binary generation during the next [[performBinaryGeneration]] call"
        shared ImmutableSetWrapper<NativeFile> jvmBackendGenerationRequired = ImmutableSetWrapper<NativeFile>();
        
        "Sources removed since the last time [[cleanRemovedFiles]] was called"
        shared ImmutableSetWrapper<NativeFile> removedSources = ImmutableSetWrapper<NativeFile>();
        
        "Source changes since the last time [[calculateDependencies]] was called"
        shared ImmutableSetWrapper<CeylonProjectsAlias.ResourceVirtualFileChange> changeEvents = ImmutableSetWrapper<CeylonProjectsAlias.ResourceVirtualFileChange>();

        shared ImmutableSetWrapper<SourceFileError> backendErrors = ImmutableSetWrapper<SourceFileError>();
        shared ImmutableSetWrapper<SourceFileError> frontendErrors = ImmutableSetWrapper<SourceFileError>();
        shared ImmutableSetWrapper<ProjectError> projectErrors = ImmutableSetWrapper<ProjectError>();
        
        shared ImmutableMapWrapper<NativeFile,Set<String>> missingClasses = ImmutableMapWrapper<NativeFile,Set<String>>();
    }
        
    State state = State();

    Boolean shouldDoFullBuild => state.fullBuildRequired && ! ceylonProject.parsed;
    Boolean shouldResolveClasspath => state.classpathResolutionRequired;

    {NativeFile*} typecheckingRequired =>
            if (state.fullBuildRequired)
                then ceylonProject.projectNativeFiles
                else state.typecheckingRequired;
    
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
    
    void setFullBuildRequired() {
        state.fullBuildRequired = true;
        state.typecheckingRequired.clear();
    }
    
    shared void classPathChanged() {
        setFullBuildRequired();
    }
    
    shared void requestFullBuild() {
        setFullBuildRequired();
        state.classpathResolutionRequired = true;
    }
    
    shared void requestCleanBuild() {
        setFullBuildRequired();
    }
    
    shared default void analyzeChanges({ChangeToAnalyze*} changes) {
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
        
        for (change in changes) {
            switch(change)
            case(is [NativeResourceChange, NativeProject]) {
                // Change outside project sources or resources
                value [nonModelChange, changeProject] = change;
                value resource = nonModelChange.resource;
                switch(nonModelChange)
                case(is NativeFolderRemoval) {
                    if (exists relativePath = vfsServices.getProjectRelativePath(resource),
                        exists [outputRepo, _, __] = outputRepoMap.get(changeProject),
                        outputRepo.isPrefixOf(relativePath)) {
                        state.fullBuildRequired = true;
                        state.classpathResolutionRequired = true;
                    }
                }
                case(is NativeFileChange) {
                    if (exists overridesResource, 
                        resource == overridesResource) {
                        state.fullBuildRequired = true;
                        state.classpathResolutionRequired = true;
                    }
                    if (exists [_, configResource, ideConfigResource] = outputRepoMap.get(changeProject)) {
                        if (exists configResource,
                            resource == configResource) {
                            state.fullBuildRequired = true;
                            state.classpathResolutionRequired = true;
                        }
                        if (exists ideConfigResource,
                            resource == ideConfigResource) {
                            state.fullBuildRequired = true;
                            state.classpathResolutionRequired = true;
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
                        state.fullBuildRequired = true;
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
                                
                                state.fullBuildRequired = true;
                                if (fileName == ModuleManager.\iMODULE_FILE) {
                                    state.classpathResolutionRequired = true;
                                }
                            }
                        }
                    }
                    
                }
                else {}
            }
        }
        
        ceylonProject.buildHooks.each((hook) => hook.analyzingChanges(changes, this, state));
    }
    
    shared void fileTreeChanged({<[NativeResourceChange, NativeProject]|ResourceVirtualFileChange>+} changes) {
        analyzeChanges(changes);
        
        state.changeEvents.addAll(changes.narrow<ResourceVirtualFileChange>()); 
    }
    
    shared Boolean performBuild(BaseProgressMonitor monitor) {
        variable Boolean success = false;
        try(progress = monitor.Progress(1000, "Ceylon build of project `` ceylonProject.name ``")) {
            // should do pre-build checks
            
            if (shouldResolveClasspath || shouldDoFullBuild) {
                ceylonProject.parseCeylonModel(progress.newChild(100));
            }
            progress.updateRemainingWork(900);
            //some other stuff
            if (!performTypechecking(progress.newChild(400))) {
                return false;
            }
            if (!performBinaryGeneration(progress.newChild(400))) {
                return false;
            }
            success = true;
        } finally {
            if (!success) {
                requestFullBuild();
            }
        }
        return success;
    }
    
    shared Boolean performTypechecking(BaseProgressMonitor monitor) {
        variable Boolean success = false;
        try(progress = monitor.Progress(1000, "Typechecking of project `` ceylonProject.name ``")) {
            if (!shouldDoFullBuild) {
                 calculateDependencies(progress.newChild(300));                       
            }
            progress.updateRemainingWork(700);
            // TODO do the incremental or full typecheck here
            for (fileToTypecheck in typecheckingRequired) {
                
            }
            // TODO Add the typechecker errors in the error list
            success = true;
        } finally {
            
        }
        return success;
    }

    shared Boolean performBinaryGeneration(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Binary Generation of project `` ceylonProject.name ``")) {
            
        } finally {
            
        }
        return true;
    }

    shared Boolean calculateDependencies(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Calculating dependencies on project `` ceylonProject.name ``")) {
            
        } finally {
            
        }
        return true;
    }

    shared Boolean cleanRemovedFiles(BaseProgressMonitor monitor) {
        try(progress = monitor.Progress(1000, "Cleaning removed files on project `` ceylonProject.name ``")) {
            
        } finally {
            
        }
        return true;
    }
    
// TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
// TODO :  A la fin : flusher le buildState + erreurs  sur le disque
// TODO : Au démmarrage si le build state n'est pas présent => full build.
}