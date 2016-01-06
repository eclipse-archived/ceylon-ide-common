import java.util {
    JList=List,
    Collections
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject
}

shared class DummyFolder<NativeProject,NativeResource,NativeFolder,NativeFile> 
        satisfies FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> 
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    String _path;
    
    shared new (String path="") {
        _path = path;
    }
    
    shared actual Boolean \iexists() => true;
    shared actual String path => _path;
    shared actual String name => "";
    shared actual JList<ResourceVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>> children =>
            Collections.emptyList<ResourceVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>>();

    suppressWarnings("expressionTypeNothing")
    shared actual FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>? findFile(String fileName) => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>? parent => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual String[] toPackageName(BaseFolderVirtualFile srcDir) => nothing;
    
    shared actual Integer hash =>
            (super of FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>).hash;
    shared actual Boolean equals(Object that) =>
            (super of FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>).equals(that);
    
    shared actual Nothing ceylonProject => nothing;
}
