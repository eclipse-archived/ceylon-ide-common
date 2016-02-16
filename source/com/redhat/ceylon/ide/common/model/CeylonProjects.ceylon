import ceylon.collection {
    HashMap
}

import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    LocalFileVirtualFile,
    LocalFolderVirtualFile,
    ZipFileVirtualFile
}

import java.lang {
    InterruptedException,
    JBoolean=Boolean
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
import com.redhat.ceylon.model.typechecker.context {
    TypeCache
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
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

    TypeCache.setEnabledByDefault(false);
    
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
            
    shared abstract default class VirtualFileSystem() extends VFS()
            satisfies VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile> {

        
        shared ResourceVirtualFileAlias createVirtualResource(NativeResource resource,
            NativeProject project) {
            assert (is NativeFolder | NativeFile resource);
            if (isFolder(resource)) {
                return createVirtualFolder(unsafeCast<NativeFolder>(resource), project);
            }
            else {
                return createVirtualFile(unsafeCast<NativeFile>(resource), project);
            }
        }
        
        shared formal NativeFolder? getParent(NativeResource resource);
        shared formal NativeFile? findFile(NativeFolder resource, String fileName);
        shared formal [String*] toPackageName(NativeFolder resource, NativeFolder sourceDir);
        shared formal Boolean isFolder(NativeResource resource);
        shared formal Boolean existsOnDisk(NativeResource resource);
        shared formal String getShortName(NativeResource resource);

        shared formal FileVirtualFileAlias createVirtualFile(NativeFile file, NativeProject project);
        shared formal FileVirtualFileAlias createVirtualFileFromProject(NativeProject project, Path path);
        shared formal FolderVirtualFileAlias createVirtualFolder(NativeFolder folder, NativeProject project);
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