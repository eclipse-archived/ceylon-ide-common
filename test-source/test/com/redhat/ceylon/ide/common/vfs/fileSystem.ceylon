import java.io {
    JFile = File
}
import ceylon.file {
    Path
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    LocalFolderVirtualFile
}
import ceylon.test {
    test
}

shared class LocalFileSystemTest() extends BaseTest<JFile, JFile, JFile>() {
    shared actual Path rootCeylonPath => resourcesRoot.childResource("local").path;
    
    shared actual FolderVirtualFile<JFile,JFile,JFile> rootVirtualFile =>
            LocalFolderVirtualFile(JFile(rootCeylonPath.absolutePath.string));
    
    test
    shared void testLocalResources() => testResourceTree();
}