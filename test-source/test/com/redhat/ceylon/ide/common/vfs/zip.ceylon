import ceylon.file {
    Path,
    createZipFileSystem,
    Directory,
    File
}
import ceylon.test {
    test
}

import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    ZipFileVirtualFile
}

import java.io {
    JFile=File
}

shared class ZipFileSystemTest() extends BaseTest<Nothing, Nothing, Nothing>() {
     suppressWarnings("expressionTypeNothing")
     value sourceZip = if (is Directory zipDir = resourcesRoot.childResource("zip"),
                            is File sz = zipDir.childResource("source.zip"))
                                then sz
                                else nothing;
                        
    suppressWarnings("expressionTypeNothing")
    shared actual Path rootCeylonPath = createZipFileSystem(sourceZip).rootPaths.first else nothing;
    
    shared actual FolderVirtualFile<Nothing,Nothing,Nothing> rootVirtualFile =
            ZipFileVirtualFile.FromFile(JFile(sourceZip.path.absolutePath.string));

    shared actual String pathFromCeylonResource(File|Directory fileOrDir) 
            => let(innerPath = fileOrDir.path.string.trimTrailing('/'.equals))
                    if (innerPath.empty) 
                        then sourceZip.path.absolutePath.string
                        else "`` sourceZip.path.absolutePath ``!`` innerPath ``";
    
    shared actual String nameFromCeylonResource(File|Directory fileOrDir) 
            => fileOrDir.path.elements.last?.trimTrailing('/'.equals) else "";

    test
    shared void testZipResources() => testResourceTree();
}