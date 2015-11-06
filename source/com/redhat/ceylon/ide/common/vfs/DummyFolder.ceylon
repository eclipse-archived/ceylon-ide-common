import java.util {
    JList=List,
    Collections
}

shared class DummyFolder<NativeResource,NativeFolder,NativeFile> 
        satisfies FolderVirtualFile<NativeResource,NativeFolder,NativeFile> 
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
    shared actual JList<ResourceVirtualFile<NativeResource,NativeFolder,NativeFile>> children =>
            Collections.emptyList<ResourceVirtualFile<NativeResource,NativeFolder,NativeFile>>();

    suppressWarnings("expressionTypeNothing")
    shared actual FileVirtualFile<NativeResource,NativeFolder,NativeFile>? findFile(String fileName) => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual FolderVirtualFile<NativeResource,NativeFolder,NativeFile>? parent => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual String[] toPackageName(BaseFolderVirtualFile srcDir) => nothing;
    
    shared actual Integer hash =>
            (super of FolderVirtualFile<NativeResource,NativeFolder,NativeFile>).hash;
    shared actual Boolean equals(Object that) =>
            (super of FolderVirtualFile<NativeResource,NativeFolder,NativeFile>).equals(that);
    
}
