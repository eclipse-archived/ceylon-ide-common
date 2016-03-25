import com.redhat.ceylon.common {
    Backend
}
import com.redhat.ceylon.ide.common.util {
    ImmutableMapWrapper,
    ImmutableSetWrapper
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}

shared class CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>(ceylonProject)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> ceylonProject;
    
    class State() {
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
    }
        
    State state = State();
        
    Boolean shouldDoFullBuild => state.fullBuildRequired && ! ceylonProject.parsed;
    Boolean shouldResolveClasspath = state.classpathResolutionRequired;

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
    
    value backendErrors_ = ImmutableSetWrapper<SourceFileError>();
    value frontendErrors_ = ImmutableSetWrapper<SourceFileError>();
    value projectErrors_ = ImmutableSetWrapper<ProjectError>();
    
    shared Set<SourceFileError> backendErrors => backendErrors_.immutable;
    shared Set<SourceFileError> frontendErrors => frontendErrors_.immutable;
    shared {SourceFileError*} sourceFileErrors => frontendErrors_.immutable.chain(backendErrors_.immutable);
    shared Set<ProjectError> projectErrors => projectErrors_.immutable;
    shared {Error*} errors => sourceFileErrors.chain(projectErrors_.immutable);

    value missingClasses_ = ImmutableMapWrapper<NativeFile,Set<String>>();
    
    shared Map<NativeFile,Set<String>> missingClasses => missingClasses_.immutable;
    
    
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
        state.classpathResolutionRequired = true;
    }
    
    shared void fileTreeChanged({CeylonProjectsAlias.ResourceVirtualFileChange+} changes) {
        for (change in changes) {
            
        }
        // TODO Faire la modification du modèle (ajout dans le liste les files en cours, etc ...) avant ou après la mise à jour de changedEvents_ ??
        state.changeEvents.addAll(changes); 
    }
// TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
// TODO :  A la fin : flusher le buildState + erreurs  sur le disque
// TODO : Au démmarrage si le build state n'est pas présent => full build.
}