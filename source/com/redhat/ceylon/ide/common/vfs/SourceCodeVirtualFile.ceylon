import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.ide.common.util {
    Path
}

import java.io {
    ByteArrayInputStream,
    InputStream
}

shared class SourceCodeVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>
        (String fileContent, Path? fullPath, 
            NativeProject? project, NativeFile? file, 
            shared actual String charset = "utf8")
        satisfies FileVirtualFile<NativeProject, NativeResource,NativeFolder,NativeFile> 
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    shared actual InputStream inputStream 
            = ByteArrayInputStream(javaString(fileContent)
                    .getBytes(charset));
    
    shared actual String name;
    shared actual String path;
    if (exists fullPath) {
        path = fullPath.string;
        name = fullPath.file.name;
    } else {
        path = "unknown.ceylon";
        name = "unknown.ceylon";
    }
    
    shared actual Boolean \iexists() => true;
    
    shared actual Integer hash
                => (super of FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>).hash;
    
    shared actual Boolean equals(Object that)
            => (super of FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>).equals(that);
    
    //TODO: the following is all really crap!
    
    suppressWarnings("expressionTypeNothing")
    shared actual NativeProject nativeProject => project else nothing;
    
    suppressWarnings("expressionTypeNothing")
    shared actual NativeFile nativeResource => file else nothing;
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing parent => nothing;
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing ceylonProject => nothing;
    
}
