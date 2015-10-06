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
import ceylon.interop.java {
    CeylonIterable
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

shared interface ResourceVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing> 
        of FileVirtualFile<NativeResource, NativeFolder, NativeFile> 
        | FolderVirtualFile<NativeResource, NativeFolder, NativeFile> 
        satisfies BaseResourceVirtualFile
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource
{
    shared formal NativeResource nativeResource;

    shared formal actual JList<out ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>> children;
    shared actual formal FolderVirtualFile<NativeResource, NativeFolder, NativeFile>? parent;
    shared actual default {ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>*} childrenIterable => CeylonIterable(children);
}

shared interface BaseFolderVirtualFile
        satisfies BaseResourceVirtualFile {
    shared actual Boolean folder => true;
    shared actual Null inputStream => null;
    shared formal BaseFileVirtualFile? findFile(String fileName);
    shared formal [String*] toPackageName(BaseFolderVirtualFile srcDir);
}

shared interface FolderVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing>
        satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> & BaseFolderVirtualFile
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual formal NativeFolder nativeResource;
    shared actual formal FileVirtualFile<NativeResource, NativeFolder, NativeFile>? findFile(String fileName);
}

shared interface BaseFileVirtualFile 
        satisfies BaseResourceVirtualFile {
    shared actual formal InputStream inputStream;
    shared formal String? charset;
    shared actual Boolean folder => false;
    shared actual default JList<out BaseResourceVirtualFile> children => Collections.emptyList<BaseFileVirtualFile>();
}

shared interface FileVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing> 
        satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> & BaseFileVirtualFile 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual JList<out ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>> children => Collections.emptyList<FileVirtualFile<NativeResource, NativeFolder, NativeFile>>();
    shared actual formal NativeFile nativeResource;
}
