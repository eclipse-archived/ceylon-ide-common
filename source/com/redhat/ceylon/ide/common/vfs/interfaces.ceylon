import java.util {
    JList=List,
    Collections
}
import java.io {
    InputStream
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    CeylonProjects
}
import com.redhat.ceylon.ide.common.util {
    equalsWithNulls
}

shared interface WithParentVirtualFile satisfies VirtualFile {
    shared formal VirtualFile? parent;
}

shared interface BaseResourceVirtualFile
        satisfies WithParentVirtualFile {
    shared actual default Integer hash 
            => path.hash;
    
    shared actual default Boolean equals(Object that)
            => if (is VirtualFile that)
    then that.path == path
    else false;
    
    shared actual Integer compareTo(VirtualFile t)
            => switch(path <=> t.path) 
    case (smaller) -1
    case (equal) 0
    case (larger) 1;
    
    shared formal actual InputStream? inputStream;
    
    shared formal actual JList<out BaseResourceVirtualFile> children;
    shared actual formal BaseFolderVirtualFile? parent;
    shared default {BaseResourceVirtualFile*} childrenIterable => CeylonIterable(children);
}

shared interface ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        of FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        | FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        satisfies BaseResourceVirtualFile
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared formal NativeResource nativeResource;
    shared formal CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>? ceylonProject;

    shared formal NativeProject nativeProject;
    shared formal CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>.VirtualFileSystem vfs;

    shared formal actual JList<out ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> children;
    shared actual default FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? parent =>
            if (exists folderParent = vfs.getParent(nativeResource))
            then vfs.createVirtualFolder(folderParent, nativeProject)
            else null;
    
    shared actual default {ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} childrenIterable => CeylonIterable(children);
    
    shared actual default Boolean \iexists() => vfs.existsOnDisk(nativeResource);
    
    shared formal FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolder;
    shared formal Boolean? isSource;
    shared formal Package? ceylonPackage;
    
    shared actual default Boolean equals(Object that) => 
            if (is ResourceVirtualFile<out Object,out Object,out Object,out Object> that) 
            then nativeResource == that.nativeResource && 
                    nativeProject==that.nativeProject
            else false;
    
    shared actual default Integer hash {
        variable value hash = 1;
        hash = 31*hash + nativeResource.hash;
        hash = 31*hash + nativeProject.hash;
        return hash;
    }
}

shared interface BaseFolderVirtualFile
        satisfies BaseResourceVirtualFile {
    shared actual Boolean folder => true;
    shared actual Null inputStream => null;
    shared formal BaseFileVirtualFile? findFile(String fileName);
    shared formal [String*] toPackageName(BaseFolderVirtualFile srcDir);
}

shared interface FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> & BaseFolderVirtualFile
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual formal NativeFolder nativeResource;

    shared actual default [String*] toPackageName(BaseFolderVirtualFile srcDir) {
        assert(is FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir);
        return vfs.toPackageName(nativeResource, srcDir.nativeResource);
    }

    shared actual default FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>? findFile(String fileName) =>
            if (exists nativeFile = vfs.findFile(nativeResource, fileName))
            then vfs.createVirtualFile(nativeFile, nativeProject)
            else null;

    shared default Boolean isRoot =>
            equalsWithNulls(rootFolder, this);
}

shared interface BaseFileVirtualFile 
        satisfies BaseResourceVirtualFile {
    shared actual formal InputStream inputStream;
    shared formal String? charset;
    shared actual Boolean folder => false;
    shared actual default JList<out BaseResourceVirtualFile> children => Collections.emptyList<BaseFileVirtualFile>();
}

shared interface FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        satisfies ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> & BaseFileVirtualFile 
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual JList<out ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> children => Collections.emptyList<FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();
    shared actual formal NativeFile nativeResource;
    
    shared actual FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolder =>
            parent?.rootFolder;
    
    shared actual Boolean? isSource =>
            parent?.isSource;

    shared actual Package? ceylonPackage =>
            parent?.ceylonPackage;
}
