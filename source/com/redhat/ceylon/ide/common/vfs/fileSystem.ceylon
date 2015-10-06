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
    Collections
}

alias LocalResourceVirtualFileAlias => ResourceVirtualFile<File, File, File>;
alias LocalFolderVirtualFileAlias => FolderVirtualFile<File, File, File>;
alias LocalFileVirtualFileAlias => FileVirtualFile<File, File, File>;

String normalizeSeparators(String path) 
        => if ('\\' == File.separatorChar)
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
            satisfies FileVirtualFile<File, File, File> & 
                       FileSystemVitualFile {
    shared actual File file;
    
    name => (super of FileSystemVitualFile).name;
    
    path => (super of FileSystemVitualFile).path;
    
    parent => (super of FileSystemVitualFile).parent;

    \iexists() => file.\iexists();
    
    throws(`class RuntimeException`)
    shared actual InputStream inputStream {
        try {
            return FileInputStream( file );
        } catch (FileNotFoundException e) {
            throw RuntimeException(e);
        }
    }

    equals(Object that) => (super of FileVirtualFile<File,File,File>).equals(that);
    
    hash => (super of FileVirtualFile<File,File,File>).hash;

    string => StringBuilder()
                .append("FileSystemVirtualFile")
                .append("{name='")
                .append( file.name )
                .appendCharacter('\'')
                .appendCharacter('}')
                .string;
    
    charset => null;

    nativeResource => file;
}

shared class LocalFolderVirtualFile(file) 
            satisfies FolderVirtualFile<File, File, File> &
                       FileSystemVitualFile {
    shared actual File file;
    
    name => (super of FileSystemVitualFile).name;
    
    path => (super of FileSystemVitualFile).path;
    
    parent => (super of FileSystemVitualFile).parent;
    
    \iexists() => file.\iexists();
    
    children 
        => let(ObjectArray<File>? theChildren = file.listFiles())
                if (exists folderChildren = theChildren)
                    then JavaList(folderChildren.array.coalesced
                                .map {
                                    LocalResourceVirtualFileAlias collecting(File f) 
                                            => if (f.directory)
                                                then LocalFolderVirtualFile(f)
                                                else LocalFileVirtualFile(f);
                                }.sequence())
                    else Collections.emptyList<ResourceVirtualFile<File, File, File>>();

    equals(Object that) => (super of FolderVirtualFile<File,File,File>).equals(that);
    
    hash => (super of FolderVirtualFile<File,File,File>).hash;
    
    string => StringBuilder()
                .append("FileSystemVirtualFile")
                .append("{name='")
                .append( file.name )
                .appendCharacter('\'')
                .appendCharacter('}')
                .string;
    
    findFile(String fileName)
        => file.listFiles(
                object satisfies FilenameFilter {
                    accept(File dir, String name)
                        => name == fileName;
                }
            ).iterable.coalesced.map {
                    collecting(File? file) 
                        => if (exists file, file.directory)
                            then LocalFileVirtualFile(file) 
                            else null;
                    }.first;
    
    nativeResource => file;
    
    shared actual String[] toPackageName(BaseFolderVirtualFile srcDir) {
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
