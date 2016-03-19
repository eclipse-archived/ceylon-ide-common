import com.redhat.ceylon.ide.common.vfs {
    FileVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.ide.common.util {
    Path,
    ImmutableMapWrapper
}
import ceylon.collection {
    HashMap,
    ArrayList
}

shared class CeylonProjectBuildState<NativeProject, NativeResource, NativeFolder, NativeFile>(BaseCeylonProject ceylonProject)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    variable value fullBuildRequired_ = true;
    variable value classpathResolutionRequired_ = true;
        
    shared Boolean shouldDoFullBuild => fullBuildRequired_ && ! ceylonProject.parsed;
    shared Boolean shouldResolveClasspath = classpathResolutionRequired_;
    
    class ChangedProjectFileState() {
        shared variable Boolean typecheckRequired = true;
        shared variable Boolean jvmBackendGenerationRequired = true;
        shared ArrayList<String> typecheckingErrors = ArrayList<String>();
        shared ArrayList<String> backendErrors = ArrayList<String>();
        shared variable Boolean missingGeneratedClasses = false;
    }
    
    value filesToBuild = ImmutableMapWrapper(HashMap<FileVirtualFileAlias, ChangedProjectFileState>());
    
    shared {FileVirtualFileAlias*} projectFilesMissingGeneratedClasses =>
            filesToBuild.filter((entry) => entry.item.missingGeneratedClasses)
                            .map((entry) => entry.key);
    
    shared void classPathChanged() {
        fullBuildRequired_ = true;
    }
    
    shared void requestFullBuild() {
        fullBuildRequired_ = true;
        classpathResolutionRequired_ = true;
    }
    
    shared void requestCleanBuild() {
        fullBuildRequired_ = true;
    }
    
    shared void fileContentChanged(FileVirtualFileAlias file) {
        
    }

    shared void fileAdded(FileVirtualFileAlias file) {
        
    }
    
    shared void fileRemoved(
        FileVirtualFileAlias file, 
        "if [[file]] has been removed after a move or rename,
         this indicates the new file to which [[file]] has been moved or renamed."
        FileVirtualFileAlias? movedTo) {
        
    }

    shared void folderAdded(FileVirtualFileAlias file) {
        
    }

    shared void folderRemoved(
        FolderVirtualFileAlias folder,
        "if [[folder]] has been removed after a move or rename,
         this indicates the new file to which [[folder]] has been moved or renamed."
        FolderVirtualFileAlias? movedTo) {
        
    }
    
    shared void fileTreeChanged(
        {FileVirtualFileAlias*} fileContentChanged = {},
        {FileVirtualFileAlias*} fileAdded = {},
        {FileVirtualFileAlias[2]*} fileRemoved = {},
        {FolderVirtualFileAlias*} folderAdded = {},
        {FolderVirtualFileAlias[2]*} folderRemove = {}
    ) {
        
    }

}