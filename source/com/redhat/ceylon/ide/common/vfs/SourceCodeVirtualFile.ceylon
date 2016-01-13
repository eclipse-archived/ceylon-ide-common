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
import java.lang {
    System
}

shared class SourceCodeVirtualFile<NativeProject, NativeResource,NativeFolder,NativeFile> 
        satisfies FileVirtualFile<NativeProject, NativeResource,NativeFolder,NativeFile> 
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    InputStream stream;
    String _path;
    String _name;
    String _charset;
    
    shared new (String fileContent, Path? path = null, String? charset=null) {
        _charset = charset else (System.getProperty("file.encoding") else "utf8");
        stream = ByteArrayInputStream(javaString(fileContent).getBytes(_charset));
        if (exists path) {
            _path = path.string;
            _name = path.file.name;
        } else {
            _path = "unknown.ceylon";
            _name = "unknown.ceylon";
        }
    }
    
    shared actual Boolean \iexists() => true;
    
    shared actual InputStream inputStream =>
            stream;
    
    shared actual String string {
        value sb = StringBuilder();
        sb.append("SourceCodeVirtualFile");
        return sb.string;
    }

    shared actual String? charset => _charset;
    shared actual String name => _name;
    shared actual String path => _path;
    
    shared actual Integer hash =>
            (super of FileVirtualFile<NativeProject, NativeResource,NativeFolder,NativeFile>).hash;
    
    shared actual Boolean equals(Object that) =>
            (super of FileVirtualFile<NativeProject, NativeResource,NativeFolder,NativeFile>).equals(that);
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing parent => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing ceylonProject => nothing;
}
