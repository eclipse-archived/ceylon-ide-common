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

shared interface WithParentVirtualFile satisfies VirtualFile {
    shared formal VirtualFile? parent;
}

shared interface ResourceVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing> 
        of FileVirtualFile<NativeResource, NativeFolder, NativeFile> 
        | FolderVirtualFile<NativeResource, NativeFolder, NativeFile> 
        satisfies WithParentVirtualFile
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource
{
    shared formal NativeResource nativeResource;
    
    shared actual default Integer hash 
            => path.hash;
    
    shared actual default Boolean equals(Object that)
            => if (is VirtualFile that)
    then that.path == path
    else false;
    
    shared formal actual InputStream? inputStream;
    
    shared formal actual JList<out ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>> children;
    
    shared actual formal FolderVirtualFile<NativeResource, NativeFolder, NativeFile>? parent;
}

shared interface FolderVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing>
        satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual formal NativeFolder nativeResource;
    shared actual Boolean folder => true;
    shared actual Null inputStream => null;
    shared formal FileVirtualFile<NativeResource, NativeFolder, NativeFile>? findFile(String fileName);
    shared formal [String*] toPackageName(FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir);
}

shared interface FileVirtualFile<NativeResource=Nothing, NativeFolder=Nothing, NativeFile=Nothing> 
        satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual JList<out ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>> children => Collections.emptyList<FileVirtualFile<NativeResource, NativeFolder, NativeFile>>();
    shared actual formal NativeFile nativeResource;
    shared actual Boolean folder => false;
    shared actual formal InputStream inputStream;
    shared formal String? charset;
}
