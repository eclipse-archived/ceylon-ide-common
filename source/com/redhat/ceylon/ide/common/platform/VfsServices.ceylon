import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    FolderVirtualFile
}
import java.lang.ref {
    WeakReference
}
import com.redhat.ceylon.ide.common.model {
    ModelAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast
}
import java.io {
    File
}

shared interface VfsServices<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    

    shared ResourceVirtualFileAlias createVirtualResource(NativeResource resource,
        NativeProject project) {
        assert (is NativeFolder | NativeFile resource);
        if (isFolder(resource)) {
            return createVirtualFolder(unsafeCast<NativeFolder>(resource), project);
        }
        else {
            return createVirtualFile(unsafeCast<NativeFile>(resource), project);
        }
    }
    
    shared formal NativeFolder? getParent(NativeResource resource);
    shared formal NativeFile? findFile(NativeFolder resource, String fileName);
    shared formal NativeResource? findChild(NativeFolder parent, Path path);
    shared formal [String*] toPackageName(NativeFolder resource, NativeFolder sourceDir);
    shared formal Boolean isFolder(NativeResource resource);
    shared formal Boolean existsOnDisk(NativeResource resource);
    shared formal String getShortName(NativeResource resource);
    shared formal Path getVirtualFilePath(NativeResource resource);
    shared formal String getVirtualFilePathString(NativeResource resource);
    shared formal Path? getProjectRelativePath(NativeResource resource);
    shared formal String? getProjectRelativePathString(NativeResource resource);
    shared formal File? getJavaFile(NativeResource resource);
    shared formal NativeResource? fromJavaFile(File javaFile, NativeProject project);

    shared Boolean isDescendantOfAny(NativeResource resource, {NativeFolder*} possibleAncestors) =>
            let(descendantPath = getVirtualFilePath(resource))
            possibleAncestors.any((ancestor) => 
                getVirtualFilePath(ancestor).isPrefixOf(descendantPath));

    shared formal FileVirtualFileAlias createVirtualFile(NativeFile file, NativeProject project);
    shared formal FileVirtualFileAlias createVirtualFileFromProject(NativeProject project, Path path);
    shared formal FolderVirtualFileAlias createVirtualFolder(NativeFolder folder, NativeProject project);
    shared formal FolderVirtualFileAlias createVirtualFolderFromProject(NativeProject project, Path path);
    
       
    shared formal void setPackagePropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder, WeakReference<Package> p);
    shared formal WeakReference<Package>? getPackagePropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder);
    shared formal void removePackagePropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder);
    
    shared formal void setRootPropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder, WeakReference<FolderVirtualFileAlias> root);
    shared formal WeakReference<FolderVirtualFileAlias>? getRootPropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder);
    shared formal void removeRootPropertyForNativeFolder(CeylonProjectAlias ceylonProject, NativeFolder folder);
    
    shared formal void setRootIsSourceProperty(CeylonProjectAlias ceylonProject, NativeFolder rootFolder, Boolean isSource);
    shared formal Boolean? getRootIsSourceProperty(CeylonProjectAlias ceylonProject, NativeFolder rootFolder);
    shared formal void removeRootIsSourceProperty(CeylonProjectAlias ceylonProject, NativeFolder rootFolder);
}