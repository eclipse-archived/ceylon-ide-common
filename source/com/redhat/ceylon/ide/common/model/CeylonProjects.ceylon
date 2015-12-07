import ceylon.collection {
    HashMap
}

import com.redhat.ceylon.ide.common.util {
    Path
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    LocalFileVirtualFile,
    LocalFolderVirtualFile,
    ZipFileVirtualFile
}

import java.lang {
    InterruptedException
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    Lock
}
import com.redhat.ceylon.compiler.typechecker.io {
    VFS,
    VirtualFile,
    ClosableVirtualFile
}
import java.io {
    File
}
import java.util.zip {
    ZipFile
}

shared abstract class BaseCeylonProjects() {
    
}


shared abstract class CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProjects()
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeResource, NativeFolder, NativeFile>
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

    shared abstract default class VirtualFileSystem() extends VFS()
            satisfies VfsAliases<NativeResource, NativeFolder, NativeFile> {

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
        
        shared actual VirtualFile getFromFile(File file) =>
                if (file.directory) 
                then LocalFolderVirtualFile(file) 
                else LocalFileVirtualFile(file);
        
        shared actual VirtualFile getFromZipFile(ZipFile zipFile) =>
                ZipFileVirtualFile(zipFile);
        
        shared actual ClosableVirtualFile getFromZipFile(File zipFile) =>
                ZipFileVirtualFile(ZipFile(zipFile), true);
        
        shared actual ClosableVirtualFile? openAsContainer(VirtualFile virtualFile) =>
                switch(virtualFile)
                case(is ZipFileVirtualFile) virtualFile
                case(is LocalFileVirtualFile) getFromZipFile(virtualFile.file)
                else null;
    }
    
    shared formal VirtualFileSystem vfs;
}