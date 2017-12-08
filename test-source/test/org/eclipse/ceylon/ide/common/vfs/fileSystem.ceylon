import ceylon.file {
    Path
}
import ceylon.test {
    test
}
import org.eclipse.ceylon.ide.common.vfs {
    FolderVirtualFile,
    LocalFolderVirtualFile
}
import java.io {
    JFile=File
}

shared class LocalFileSystemTest() extends BaseTest() {
    shared actual Path rootCeylonPath = resourcesRoot.childResource("local").path;
    
    shared actual FolderVirtualFile<Nothing,JFile,JFile,JFile> rootVirtualFile =
            LocalFolderVirtualFile(JFile(rootCeylonPath.absolutePath.string));
    
    test
    shared void testLocalResources() => testResourceTree();
}
