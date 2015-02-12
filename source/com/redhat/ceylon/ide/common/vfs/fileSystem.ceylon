import ceylon.interop.java {
    JavaList
}

import java.io {
    File,
    InputStream,
    FileInputStream,
    FileNotFoundException,
    FilenameFilter
}
import java.lang {
    RuntimeException,
    ObjectArray
}
import java.util {
    JList=List,
    Collections
}

alias LocalResourceVirtualFileAlias => ResourceVirtualFile<File, File, File>;
alias LocalFolderVirtualFileAlias => FolderVirtualFile<File, File, File>;
alias LocalFileVirtualFileAlias => FileVirtualFile<File, File, File>;

String normalizeSeparators(String path) =>
    if ('\\' == File.separatorChar)
        then path.replace("\\", "/")
        else path;


shared interface FileSystemVitualFile satisfies WithParentVirtualFile{
    shared formal File file;

    shared actual default String name 
        => file.name;

    shared actual default String path
        => normalizeSeparators(file.path);
    
    shared actual default FolderVirtualFile<File,File,File>? parent 
        => if (exists nativeParent = file.parentFile)
            then LocalFolderVirtualFile(nativeParent)
            else null;
}    
    
shared class LocalFileVirtualFile(file)
            satisfies FileVirtualFile<File, File, File>, 
                       FileSystemVitualFile {
    shared actual File file;
    
    shared actual String name 
        => (super of FileSystemVitualFile).name;
    
    shared actual String path
        => (super of FileSystemVitualFile).path;
    
    shared actual FolderVirtualFile<File,File,File>? parent
        => (super of FileSystemVitualFile).parent;

    throws(`class RuntimeException`)
    shared actual InputStream inputStream {
        try {
            return FileInputStream( file );
        } catch (FileNotFoundException e) {
            throw RuntimeException(e);
        }
    }

    shared actual Boolean equals(Object that)
            => (super of FileVirtualFile<File,File,File>).equals(that);
    
    shared actual Integer hash
            => (super of FileVirtualFile<File,File,File>).hash;
    
    shared actual String string
        => StringBuilder()
            .append("FileSystemVirtualFile")
            .append("{name='")
            .append( file.name )
            .appendCharacter('\'')
            .appendCharacter('}')
            .string;
    
    shared actual String? charset => null;

    shared actual File nativeResource => file;
}

shared class LocalFolderVirtualFile(file) 
            satisfies FolderVirtualFile<File, File, File>,
                       FileSystemVitualFile {
    shared actual File file;
    
    shared actual String name 
        => (super of FileSystemVitualFile).name;
    
    shared actual String path
        => (super of FileSystemVitualFile).path;
    
    shared actual FolderVirtualFile<File,File,File>? parent
            => (super of FileSystemVitualFile).parent;
    
    shared actual JList<ResourceVirtualFile<File, File, File>> children 
        => let(ObjectArray<File>? theChildren = file.listFiles())
                if (exists folderChildren = theChildren)
                    then JavaList(folderChildren.array.coalesced
                                .map {
                                    LocalResourceVirtualFileAlias collecting(File f) =>
                                            if (f.directory)
                                                then LocalFolderVirtualFile(f)
                                                else LocalFileVirtualFile(f);
                                }.sequence())
                    else Collections.emptyList<ResourceVirtualFile<File, File, File>>();

    shared actual Boolean equals(Object that)
            => (super of FolderVirtualFile<File,File,File>).equals(that);
    
    shared actual Integer hash
            => (super of FolderVirtualFile<File,File,File>).hash;
    
    shared actual String string
            => StringBuilder()
            .append("FileSystemVirtualFile")
            .append("{name='")
            .append( file.name )
            .appendCharacter('\'')
            .appendCharacter('}')
            .string;
    
    shared actual FileVirtualFile<File,File,File>? findFile(String fileName)
        => file.listFiles(
                object satisfies FilenameFilter {
                    accept(File dir, String name)
                        => name == fileName;
                }
            ).array.coalesced.map {
                    collecting(File? file) 
                        => if (exists file, file.directory)
                            then LocalFileVirtualFile(file) 
                            else null;
                    }.first;
    
    shared actual File nativeResource => file;
    
    shared actual String[] toPackageName(FolderVirtualFile<File,File,File> srcDir) {
        if (is LocalFolderVirtualFile srcDir) {
            value fileAbsolutePath = file.absolutePath;
            value sourceDirAbsolutePath = srcDir.nativeResource.absolutePath;
            
            if (fileAbsolutePath.startsWith(sourceDirAbsolutePath)) {
                value relativePath = fileAbsolutePath.replaceFirst(sourceDirAbsolutePath, "");
                return normalizeSeparators(relativePath).split('/'.equals).sequence();
            }
        }
        return [];
    }
}
