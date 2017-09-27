import ceylon.collection {
    TreeSet
}

import org.eclipse.ceylon.compiler.typechecker.io {
    ClosableVirtualFile,
    VirtualFile
}
import org.eclipse.ceylon.compiler.typechecker.io.impl {
    Helper
}
import org.eclipse.ceylon.ide.common.util {
    synchronize
}

import java.io {
    InputStream,
    IOException,
    FilterInputStream,
    File
}
import java.util {
    Collections,
    ArrayList,
    LinkedList,
    JList=List
}
import java.util.zip {
    ZipEntry,
    ZipFile
}

shared class ZipFolderVirtualFile(entryName, String rootPath) satisfies BaseFolderVirtualFile {
    shared String entryName;
    JList<BaseResourceVirtualFile> theChildren = ArrayList<BaseResourceVirtualFile>();
    
    path = "``rootPath``!/``entryName``".trimTrailing('/'.equals);
    name = Helper.getSimpleName(entryName);
    shared actual variable BaseFolderVirtualFile? parent = null;
    
    shared actual default String? getRelativePath(VirtualFile ancestor) {
        if (is ZipFolderVirtualFile ancestor) {
            return super.getRelativePath(ancestor);
        }
        if (is ZipFileVirtualFile ancestor) {
            if (path == ancestor.path) {
                return "";
            }
            value pathWihArchiveSep = ancestor.path + "!/";
            if (path.startsWith(pathWihArchiveSep)) {
                return path.removeInitial(pathWihArchiveSep);
            }
        }
        return null;
    }

    children => Collections.unmodifiableList( theChildren );
    
    shared void addChild(BaseResourceVirtualFile child)
            => theChildren.add(child);
    
    string => StringBuilder()
            .append("ZipFolderVirtualFile")
            .append("{name='")
            .append(name).appendCharacter('\'')
            .appendCharacter('}')
            .string;
    
    findFile(String fileName)
            => searchFileChildren(theChildren, fileName);
    
    toPackageName(BaseFolderVirtualFile srcDir)
            => entryName.trim('/'.equals).split("/".equals).sequence();
    
    equals(Object that) => (super of BaseFolderVirtualFile).equals(that);
    
    hash => (super of BaseFolderVirtualFile).hash;

    \iexists() => true;
}

shared class ZipEntryVirtualFile(entry, zipFile) satisfies BaseFileVirtualFile {
    ZipEntry entry;
    shared String entryName = entry.name;
    ZipFile zipFile;
    name = Helper.getSimpleName(entry);
    path = "``zipFile.name``!/``entry.name``".trimTrailing('/'.equals);
    shared variable actual BaseFolderVirtualFile? parent = null;
    \iexists() => true;
    
    shared actual String? getRelativePath(VirtualFile ancestor) {
        if (is ZipEntryVirtualFile | ZipFolderVirtualFile ancestor) {
            return super.getRelativePath(ancestor);
        }
        if (is ZipFileVirtualFile ancestor) {
            if (path == ancestor.path) {
                return "";
            }
            value pathWihArchiveSep = ancestor.path + "!/";
            if (path.startsWith(pathWihArchiveSep)) {
                return path.removeInitial(pathWihArchiveSep);
            }
        }
        return null;
    }
    
    shared actual InputStream inputStream {
        return object extends FilterInputStream(zipFile.getInputStream( entry )) {
            // Do nothing since the ZipInputStream will be closed by the ZipFile.close call
            close() => noop();
        };
    }
    
    string => StringBuilder()
            .append("ZipEntryVirtualFile")
            .append("{name='")
            .append(name)
            .appendCharacter('\'')
            .appendCharacter('}')
            .string;
    
    equals(Object that) => (super of BaseFileVirtualFile).equals(that);
    
    hash => (super of BaseFileVirtualFile).hash;
    
    charset => null;
}

ZipEntryVirtualFile? searchFileChildren(JList<BaseResourceVirtualFile> theChildren, String fileName) {
    for (vf in theChildren) {
        if (is ZipEntryVirtualFile vf, vf.name == fileName) {
            return vf;
        }
    }
    else {
        return null;
    }
}

shared class ZipFileVirtualFile satisfies ClosableVirtualFile & BaseFolderVirtualFile {
    ZipFile zipFile;
    shared actual late String name;
    variable JList<BaseResourceVirtualFile> theChildren = ArrayList<BaseResourceVirtualFile>();
    variable Boolean childrenInitialized = false;
    Boolean closeable;
    
    shared new (ZipFile aZipFile, Boolean isCloseable = false) {
        zipFile = aZipFile;
        closeable = isCloseable;
    }
    
    throws(`class IOException`)
    shared new fromFile(File file) {
        zipFile = ZipFile(file);
        closeable = true;
    }
    
    getRelativePath(VirtualFile ancestor) => ancestor == this then "";
    
    path => zipFile.name;

    shared actual JList<out BaseResourceVirtualFile> children {
        synchronize {
            on = theChildren;
            void do() {
                if (! childrenInitialized) {
                    childrenInitialized = true;
                    initializeChildren(zipFile);
                }
            }
        };
        return theChildren;
    }
    
    string => StringBuilder()
            .append("ZipFileVirtualFile")
            .append("{name='")
            .append(name)
            .appendCharacter('\'')
            .appendCharacter('}').
            string;

    shared actual void close() {
        if (closeable) {
            try {
                zipFile.close();
            }
            catch (IOException e) {
                throw Exception("error closing", e);
            }
        }
    }
    
    findFile(String fileName)
            => searchFileChildren(theChildren, fileName);
    
    parent => null;
    
    toPackageName(BaseFolderVirtualFile srcDir) => [];
    
    equals(Object that) => (super of BaseFolderVirtualFile).equals(that);
    
    hash => (super of BaseFolderVirtualFile).hash;

    \iexists() => true;
    
    void initializeChildren(ZipFile zipFile) {
        value path = zipFile.name;
        value lastIndex = path.lastIndexWhere(File.separator.equals);
        name = if (exists lastIndex) then path[lastIndex+1...] else path;
        
        function buildParents(String entry) 
                => let(parents = entry.split('/'.equals).filter(not(String.empty)).exceptLast)
        if (exists firstParent = parents.first)
        then
        if (nonempty restOfParents = parents.rest.sequence())
        then restOfParents.scan(firstParent + "/",
                    (path, nextParent) => "".join { path, nextParent + "/" })
        else { firstParent + "/"}
        else {};
        
        value entries = zipFile.entries();
        value entryNames = TreeSet<String>((x,y) => x<=>y);
        while ( entries.hasMoreElements() ) {
            value entryName = entries.nextElement().name;
            // Also add the ancestor directories (for the case directories are not in the archive)
            value parentEntriesNames = buildParents(entryName);
            entryNames.add(entryName);
            entryNames.addAll(parentEntriesNames);
        }
        
        BaseFolderVirtualFile addToParentfolder(JList<BaseResourceVirtualFile> directChildren,
                LinkedList<ZipFolderVirtualFile> directoryStack, String entryName,
                BaseResourceVirtualFile file) {

            variable ZipFolderVirtualFile? up = directoryStack.peekLast();
            
            function isChildOf(String entryName, ZipFolderVirtualFile? lastFolder)
                    => if (exists lastFolder)
                    then entryName.startsWith( lastFolder.entryName )
                    else true;
            
            while ( !isChildOf(entryName, up) ) {
                directoryStack.pollLast();
                up = directoryStack.peekLast();
            }
            if (exists existingUp = up) {
                existingUp.addChild(file);
                return existingUp;
            }
            else {
                directChildren.add(file);
                return this;
            }
        }
        
        value directChildren = ArrayList<BaseResourceVirtualFile>();
        value directoryStack = LinkedList<ZipFolderVirtualFile>();
        for ( entryName in entryNames ) {
            if ( entryName.endsWith("/")) {
                /*
                 entries are now ordered with directories,
                 if an entry is a child of the previous entry, add it as child
                 if an entry is not a child of the previous entry, move up till we find its parent
                 */
                value folder = ZipFolderVirtualFile(entryName, path);
                folder.parent = addToParentfolder(directChildren, directoryStack, entryName, folder);
                directoryStack.addLast(folder);
            }
            else {
                value entry = zipFile.getEntry(entryName);
                value file = ZipEntryVirtualFile(entry, zipFile);
                file.parent = addToParentfolder(directChildren, directoryStack, entryName, file);
            }
        }
        theChildren.addAll(directChildren);
    }
}
