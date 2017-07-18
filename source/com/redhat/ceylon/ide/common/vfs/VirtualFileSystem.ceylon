import com.redhat.ceylon.compiler.typechecker.io {
    ClosableVirtualFile,
    VFS,
    VirtualFile
}
import java.io {
    File
}
import java.util.zip {
    ZipFile
}
import java.lang {
    overloaded
}

shared class VirtualFileSystem() extends VFS() {

    overloaded
    shared actual LocalFolderVirtualFile|LocalFileVirtualFile getFromFile(File file) =>
            if (file.directory) 
                then LocalFolderVirtualFile(file) 
                else LocalFileVirtualFile(file);

    overloaded
    shared actual BaseFolderVirtualFile getFromZipFile(ZipFile zipFile) =>
            ZipFileVirtualFile(zipFile);

    overloaded
    shared actual ClosableVirtualFile&BaseFolderVirtualFile getFromZipFile(File zipFile) =>
            ZipFileVirtualFile(ZipFile(zipFile), true);
    
    shared actual ClosableVirtualFile? openAsContainer(VirtualFile virtualFile) =>
            switch(virtualFile)
            case(is ZipFileVirtualFile) virtualFile
            case(is LocalFileVirtualFile) getFromZipFile(virtualFile.file)
            else null;
}