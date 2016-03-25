import ceylon.collection {
    HashMap,
    HashSet,
    unlinked
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    VirtualFileSystem
}
import com.redhat.ceylon.model.typechecker.context {
    TypeCache
}

import java.lang {
    InterruptedException,
    JBoolean=Boolean
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    Lock
}

shared abstract class BaseCeylonProjects() {
    
}

shared T withCeylonModelCaching<T>(T() do) {
    JBoolean? was = TypeCache.setEnabled(JBoolean.\iTRUE);
    try {
        return do();
    } finally {
        TypeCache.setEnabled(was);
    }
}


shared final class ResourceChangeType
{
    shared new fileContentChange {}
    shared new fileAddition {}
    shared new fileRemoval {}
    shared new folderAddition {}
    shared new folderRemoval {}
}

shared abstract class CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProjects()
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    alias ListenerAlias => ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>;
    value modelListeners = HashSet<ListenerAlias>(unlinked);
    value projectMap = HashMap<NativeProject, CeylonProjectAlias>();
    value lock = ReentrantReadWriteLock(true);

    shared VirtualFileSystem vfs = VirtualFileSystem();

    TypeCache.setEnabledByDefault(false);
    
    shared void addModelListener(ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile> listener) =>
            modelListeners.add(listener);
    
    shared void removeModelListener(ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile> listener) =>
            modelListeners.remove(listener);

    void runListenerFunction(void fun(ListenerAlias listener)) {
        modelListeners.each((listener) {
            try {
                fun(listener);
            } catch(Exception e) {
                platformUtils.log(Status._ERROR, "A Ceylon Model listener (``listener``) has triggered the following exception:", e);
            }
        });
    }
    
    shared actual void modelParsed(CeylonProject<NativeProject,NativeResource,NativeFolder,NativeFile> project) =>
            runListenerFunction((listener)=>listener.modelParsed(project));
            
    T withLocking<T=Anything>(Boolean write, T do(), T() interrupted) {
        Lock l = if (write) then lock.writeLock() else lock.readLock();
        try {
            l.lockInterruptibly();
            try {
                return do();
            }finally {
                l.unlock();
            }
        } catch(InterruptedException e) {
            return interrupted();
        }
    }

    shared formal CeylonProjectAlias newNativeProject(NativeProject nativeProject);

    shared {CeylonProjectAlias*} ceylonProjects
        => withLocking {
            write=false;
            do() => projectMap.items.sequence();
            interrupted() => {};
        };

    shared {NativeProject*} nativeProjects
            => withLocking {
        write=false;
        do() => projectMap.keys.sequence();
        interrupted() => {};
    };
    
    shared CeylonProjectAlias? getProject(NativeProject? nativeProject)
        => withLocking {
            write=false;
            do() => if (exists nativeProject) then projectMap[nativeProject] else null;
            interrupted() => null;
        };

    shared Boolean removeProject(NativeProject nativeProject)
        => withLocking {
            write=true;
            do() => projectMap.remove(nativeProject) exists;
            function interrupted() {
                throw InterruptedException();
            }
        };

    shared Boolean addProject(NativeProject nativeProject)
        => withLocking {
            write=true;
            function do() {
                 if (projectMap[nativeProject] exists) {
                     return false;
                 } else {
                     projectMap.put(nativeProject, newNativeProject(nativeProject));
                     return true;
                 }
            }
            function interrupted() {
                 throw InterruptedException();
            }
        };

    shared void clearProjects()
        => withLocking {
            write=true;
            do() => projectMap.clear();
            function interrupted() {
                throw InterruptedException();
            }
        };

    shared {PhasedUnit*} parsedUnits
        => ceylonProjects.flatMap((ceylonProject) => ceylonProject.parsedUnits);
            

    shared abstract class ResourceChange<Resource, Folder, File>()
            of FolderChange<Resource, Folder, File>
            | FileChange<Resource, Folder, File> 
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        shared formal ResourceChangeType type;
        shared formal Resource resource;
        
        shared actual Boolean equals(Object that) => 
                if (is ResourceChange<out Object, out Object, out Object> that) 
        then type==that.type && 
                resource==that.resource 
        else false;
    }
    
    shared abstract class FileChange<Resource, Folder, File>(File theFile)
            of FileContentChange<Resource, Folder, File>
            | FileAddition<Resource, Folder, File> 
            | FileRemoval<Resource, Folder, File>
            extends ResourceChange<Resource, Folder, File>()
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
         shared actual File resource = theFile;
    }
    
    shared class FileContentChange<Resource, Folder, File>(File theFile)
            extends FileChange<Resource, Folder, File>(theFile)
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        type = ResourceChangeType.fileContentChange;
    }
    
    shared class FileAddition<Resource, Folder, File>(File theFile)
            extends FileChange<Resource, Folder, File>(theFile)
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        type = ResourceChangeType.fileAddition;
    }
    
    shared class FileRemoval<Resource, Folder, File>(
        File theFile,
        "if [[theFile]] has been removed after a move or rename,
         this indicates the new file to which [[theFile]] has been moved or renamed."
        shared File? movedTo)
            extends FileChange<Resource, Folder, File>(theFile)
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        type = ResourceChangeType.fileRemoval;
    }
    
    shared abstract class FolderChange<Resource, Folder, File>(Folder theFolder)
            of FolderAddition<Resource, Folder, File>
            | FolderRemoval<Resource, Folder, File>
            extends ResourceChange<Resource, Folder, File>()
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        shared actual Folder resource = theFolder;
    }
    
    shared class FolderAddition<Resource, Folder, File>(Folder theFolder)
            extends FolderChange<Resource, Folder, File>(theFolder)
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        type = ResourceChangeType.folderAddition;
    }
    
    shared class FolderRemoval<Resource, Folder, File>(
        Folder theFolder,
        "if [[theFolder]] has been removed after a move or rename,
         this indicates the new file to which [[theFolder]] has been moved or renamed."
        shared Folder? movedTo)
            extends FolderChange<Resource, Folder, File>(theFolder)
            given Resource satisfies Object 
            given Folder satisfies Resource 
            given File satisfies Resource {
        type = ResourceChangeType.folderRemoval;
    }
    
    shared alias NativeResourceChange => ResourceChange<NativeResource, NativeFolder, NativeFile>;
    shared alias NativeFileChange => FileChange<NativeResource, NativeFolder, NativeFile>;
    shared class NativeFileContentChange(NativeFile theFile) => FileContentChange<NativeResource, NativeFolder, NativeFile>(theFile);
    shared class NativeFileAddition(NativeFile theFile) => FileAddition<NativeResource, NativeFolder, NativeFile>(theFile);
    shared class NativeFileRemoval(NativeFile theFile, NativeFile? movedTo) => FileRemoval<NativeResource, NativeFolder, NativeFile>(theFile, movedTo);
    shared alias NativeFolderChange => FolderChange<NativeResource, NativeFolder, NativeFile>;
    shared class NativeFolderAddition(NativeFolder theFolder) => FolderAddition<NativeResource, NativeFolder, NativeFile>(theFolder);
    shared class NativeFolderRemoval(NativeFolder theFolder, NativeFolder? movedTo) => FolderRemoval<NativeResource, NativeFolder, NativeFile>(theFolder, movedTo);

    shared alias ResourceVirtualFileChange => ResourceChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared alias FileVirtualFileChange => FileChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared class FileVirtualFileContentChange(FileVirtualFileAlias theFile) => FileContentChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile);
    shared class FileVirtualFileAddition(FileVirtualFileAlias theFile) => FileAddition<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile);
    shared class FileVirtualFileRemoval(FileVirtualFileAlias theFile, FileVirtualFileAlias? movedTo) => FileRemoval<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile, movedTo);
    shared alias FolderVirtualFileChange => FolderChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared class FolderVirtualFileAddition(FolderVirtualFileAlias theFolder) => FolderAddition<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFolder);
    shared class FolderVirtualFileRemoval(FolderVirtualFileAlias theFolder, FolderVirtualFileAlias? movedTo) => FolderRemoval<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFolder, movedTo);
    
    
        
}