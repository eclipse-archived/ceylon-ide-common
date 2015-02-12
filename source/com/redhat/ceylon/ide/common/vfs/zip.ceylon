import ceylon.collection {
    TreeSet
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.io {
    ClosableVirtualFile,
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.io.impl {
    Helper
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}

import java.io {
    InputStream,
    IOException,
    FilterInputStream,
    File
}
import java.lang {
    RuntimeException
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

shared class ZipFolderVirtualFile(entryName, String rootPath) satisfies FolderVirtualFile {
    shared String entryName;
    JList<ResourceVirtualFile> theChildren = ArrayList<ResourceVirtualFile>();
    
    shared actual String path = "``rootPath``!/``entryName``".trimTrailing('/'.equals);
    shared actual String name = Helper.getSimpleName(entryName);
    shared actual variable FolderVirtualFile? parent = null;
    
    shared actual JList<out ResourceVirtualFile> children {
        return Collections.unmodifiableList( theChildren );
    }
    
    shared void addChild(ResourceVirtualFile child) {
        theChildren.add(child);
    }
    
    shared actual String string 
            => StringBuilder().append("ZipFolderVirtualFile")
            .append("{name='").append(name).appendCharacter('\'')
            .appendCharacter('}').string;
    
    shared actual ZipEntryVirtualFile? findFile(String fileName)
            => searchFileChildren(theChildren, fileName);
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource => nothing;
    
    shared actual String[] toPackageName(FolderVirtualFile<Nothing,Nothing,Nothing> srcDir)
            => entryName.trim('/'.equals).split("/".equals).sequence();
    
    shared actual Boolean equals(Object that) 
            => (super of FolderVirtualFile).equals(that); 
    
    shared actual Integer hash
            => (super of FolderVirtualFile).hash; 
}

throws(`class RuntimeException`)
shared class ZipEntryVirtualFile(entry, zipFile) satisfies FileVirtualFile {
    ZipEntry entry;
    shared String entryName = entry.name;
    ZipFile zipFile;
    shared actual String name = Helper.getSimpleName(entry);
    shared actual String path = "``zipFile.name``!/``entry.name``".trimTrailing('/'.equals);
    shared variable actual FolderVirtualFile<Nothing,Nothing,Nothing>? parent = null;
    
    shared actual InputStream inputStream {
        try {
            return object extends FilterInputStream(zipFile.getInputStream( entry )) {
                // Do nothing since the ZipInputStream will be closed by the ZipFile.close call
                shared actual void close() => noop();
            };
        }
        catch (IOException e) {
            throw RuntimeException(e);
        }
    }
    
    shared actual String string
            => StringBuilder()
            .append("ZipEntryVirtualFile")
            .append("{name='")
            .append(name)
            .appendCharacter('\'')
            .appendCharacter('}')
            .string;
    
    shared actual Boolean equals(Object that)
            => (super of FileVirtualFile).equals(that);
    
    shared actual Integer hash
            => (super of FileVirtualFile).hash;
    
    shared actual String? charset => null;
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource => nothing;
}

ZipEntryVirtualFile? searchFileChildren(JList<ResourceVirtualFile> theChildren, String fileName) {
    return CeylonIterable(theChildren).map {
        collecting(VirtualFile vf) 
                => if (is ZipEntryVirtualFile vf, vf.name == fileName)
        then vf
        else null;
    }.first;
}



shared class ZipFileVirtualFile satisfies ClosableVirtualFile, FolderVirtualFile {
    ZipFile zipFile;
    shared actual late String name;
    variable JList<ResourceVirtualFile> theChildren = ArrayList<ResourceVirtualFile>();
    variable Boolean childrenInitialized = false;
    Boolean closeable;
    
    shared new ZipFileVirtualFile(ZipFile aZipFile, Boolean isCloseable = false) {
        zipFile = aZipFile;
        closeable = isCloseable;
    }
    
    throws(`class IOException`)
    shared new FromFile(File file) {
        zipFile = ZipFile(file);
        closeable = true;
    }
    
    
    shared actual String path
            => zipFile.name;

    shared actual JList<out ResourceVirtualFile> children {
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
    
    shared actual String string
            => StringBuilder()
            .append("ZipFileVirtualFile")
            .append("{name='").append(name).appendCharacter('\'')
            .appendCharacter('}').string;
    
    throws(`class RuntimeException`)
    shared actual void close() {
        if (closeable) {
            try {
                zipFile.close();
            }
            catch (IOException e) {
                throw RuntimeException(e);
            }
        }
    }
    
    shared actual ZipEntryVirtualFile? findFile(String fileName)
            => searchFileChildren(theChildren, fileName);
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeResource
            => nothing;
    
    shared actual FolderVirtualFile<Nothing,Nothing,Nothing>? parent => null;
    
    shared actual String[] toPackageName(FolderVirtualFile<Nothing,Nothing,Nothing> srcDir)
            => [];
    
    shared actual Boolean equals(Object that)
            => (super of FolderVirtualFile).equals(that);
    
    shared actual Integer hash
            => (super of FolderVirtualFile).hash;

    void initializeChildren(ZipFile zipFile) {
        value path = zipFile.name;
        value lastIndex = path.lastIndexWhere(File.separator.equals);
        name = if (exists lastIndex) then path.spanFrom(lastIndex+1) else path;
        
        function buildParents(String entry) 
                => let(parents = entry.split('/'.equals).filter(not(String.empty)).exceptLast)
        if (exists firstParent = parents.first)
        then
        if (nonempty restOfParents = parents.rest.sequence())
        then restOfParents.scan(firstParent + "/")((path, nextParent) 
            => "".join { path, nextParent + "/"})
        else { firstParent + "/"}
        else {};
        
        value entries = zipFile.entries();
        TreeSet<String> entryNames = TreeSet<String>((x,y) => x<=> y);
        while ( entries.hasMoreElements() ) {
            String entryName = entries.nextElement().name;
            // Also add the ancestor directories (for the case directories are not in the archive)
            value parentEntriesNames = buildParents(entryName);
            entryNames.add(entryName);
            entryNames.addAll(parentEntriesNames);
        }
        
        FolderVirtualFile addToParentfolder(JList<ResourceVirtualFile> directChildren, LinkedList<ZipFolderVirtualFile> directoryStack, String entryName, ResourceVirtualFile file) {
            variable ZipFolderVirtualFile? up = directoryStack.peekLast();
            
            Boolean isChildOf(String entryName, ZipFolderVirtualFile? lastFolder) {
                if (exists lastFolder) {
                    return entryName.startsWith( lastFolder.entryName );
                } else {
                    return true;
                }
            }
            
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
        
        value directChildren = ArrayList<ResourceVirtualFile>();
        LinkedList<ZipFolderVirtualFile> directoryStack = LinkedList<ZipFolderVirtualFile>();
        for ( String entryName in entryNames ) {
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
                ZipEntry entry = zipFile.getEntry(entryName);
                ZipEntryVirtualFile file = ZipEntryVirtualFile(entry, zipFile);
                file.parent = addToParentfolder(directChildren, directoryStack, entryName, file);
            }
        }
        theChildren.addAll(directChildren);
    }
}
