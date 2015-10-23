import ceylon.collection {
    HashMap
}

import java.util.concurrent.locks { ReentrantReadWriteLock,
    Lock }
import java.lang {
    InterruptedException
}
import com.redhat.ceylon.ide.common.vfs {
    ResourceVirtualFile,
    FolderVirtualFile,
    FileVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.ide.common.util {
    Path
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit,
    CrossProjectPhasedUnit
}

shared abstract class BaseCeylonProjects() {
    
}


shared abstract class CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProjects()
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    value projectMap = HashMap<NativeProject, CeylonProjectAlias>();
    
    value lock = ReentrantReadWriteLock(true);
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
            interrupted() => false;
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
            interrupted() => false;
        };

    shared void clearProjects()
        => withLocking {
            write=true;
            do() => projectMap.clear();
            interrupted() => null;
        };

    shared abstract formal class VirtualFileSystem()
            satisfies VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile> {

        shared ResourceVirtualFileAlias createVirtualResource(NativeResource resource) {
            assert (is NativeFolder | NativeFile resource);
            if (is NativeFolder resource) {
                return createVirtualFolder(resource);
            }
            else {
                return createVirtualFile(resource);
            }
        }
        
        shared formal FileVirtualFileAlias createVirtualFile(NativeFile file);
        shared formal FileVirtualFileAlias createVirtualFileFromProject(NativeProject project, Path path);
        shared formal FolderVirtualFileAlias createVirtualFolder(NativeFolder folder);
        shared formal FolderVirtualFileAlias createVirtualFolderFromProject(NativeProject project, Path path);
    }
    
    shared formal VirtualFileSystem vfs;
}