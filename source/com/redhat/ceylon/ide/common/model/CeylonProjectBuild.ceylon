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
    Path
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}
import java.io {
    File
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
    
    
    
    shared abstract class Error(Backend theBackend=Backend.\iHeader) 
            of ProjectError | SourceFileError {
        Backend backend = theBackend;
    }

    shared class ProjectError(Backend theBackend=Backend.\iHeader)
        extends Error(theBackend) {
    }

    shared class SourceFileError (
        NativeFile theFile,
        Backend theBackend=Backend.\iHeader)  
            extends Error(theBackend) 
             {
        shared NativeFile file = theFile;
    }
    
    shared Set<SourceFileError> backendErrors => state.backendErrors.immutable;
    shared Set<SourceFileError> frontendErrors => state.frontendErrors.immutable;
    shared {SourceFileError*} sourceFileErrors => state.frontendErrors.immutable.chain(state.backendErrors.immutable);
    shared Set<ProjectError> projectErrors => state.projectErrors.immutable;
    shared {Error*} errors => sourceFileErrors.chain(state.projectErrors.immutable);

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
                    
                }
                case(is FileVirtualFileChange) {
                    // Check if a *source file* module descriptor or package descriptor is changed ( ast no changes + errors, etc ...)
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
    
    shared void performBuild() {
        
    }
    
// TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
// TODO :  A la fin : flusher le buildState + erreurs  sur le disque
// TODO : Au démmarrage si le build state n'est pas présent => full build.
}