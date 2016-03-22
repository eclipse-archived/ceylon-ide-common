import com.redhat.ceylon.ide.common.vfs {
    FileVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.ide.common.util {
    Path,
    ImmutableMapWrapper,
    ImmutableSetWrapper
}
import ceylon.collection {
    HashMap,
    ArrayList
}
import com.redhat.ceylon.common {
    Backend
}
import ceylon.interop.java {
    javaClassFromInstance
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
        shared variable Boolean fullBuildRequired_ = true;
        shared variable Boolean classpathResolutionRequired_ = true;
        
        "Sources requiring a typechecking during the next [[performTypechecking]] call"
        shared ImmutableSetWrapper<NativeFile> typecheckingRequired_ = ImmutableSetWrapper<NativeFile>();
        
        "Sources requiring a JVM binary generation during the next [[performBinaryGeneration]] call"
        shared ImmutableSetWrapper<NativeFile> jvmBackendGenerationRequired_ = ImmutableSetWrapper<NativeFile>();
        
        "Sources removed since the last time [[cleanRemovedFiles]] was called"
        shared ImmutableSetWrapper<NativeFile> removedSources_ = ImmutableSetWrapper<NativeFile>();
        
        "Source changes since the last time [[calculateDependencies]] was called"
        shared ImmutableSetWrapper<CeylonProjectsAlias.ResourceChange> changeEvents_ = ImmutableSetWrapper<CeylonProjectsAlias.ResourceChange>();
    }
        
    State state = State();
        
    Boolean shouldDoFullBuild => state.fullBuildRequired_ && ! ceylonProject.parsed;
    Boolean shouldResolveClasspath = state.classpathResolutionRequired_;

    {NativeFile*} typecheckingRequired =>
            if (state.fullBuildRequired_)
    then ceylonProject.projectNativeFiles
    else state.typecheckingRequired_;
    
    
    
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
        state.fullBuildRequired_ = true;
        state.typecheckingRequired_.clear();
    }
    
    shared void classPathChanged() {
        setFullBuildRequired();
    }
    
    shared void requestFullBuild() {
        setFullBuildRequired();
        state.classpathResolutionRequired_ = true;
    }
    
    shared void requestCleanBuild() {
        setFullBuildRequired();
        state.classpathResolutionRequired_ = true;
    }
    
    shared void fileTreeChanged({CeylonProjectsAlias.ResourceChange+} changes) {
        for (change in changes) {
            
        }
        // TODO Faire la modification du modèle (ajout dans le liste les files en cours, etc ...) avant ou après la mise à jour de changedEvents_ ??
        state.changeEvents_.addAll(changes); 
    }
// TODO : au démarrage : charger le buildState + erreurs depuis le disque et effacer le build state du disque
// TODO :  A la fin : flusher le buildState + erreurs  sur le disque
// TODO : Au démmarrage si le build state n'est pas présent => full build.
}