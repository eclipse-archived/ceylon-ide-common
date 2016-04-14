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
    Status,
    ModelServicesConsumer,
    VfsServicesConsumer
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

shared abstract class CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProjects()
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
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
    
    
    "Dispatch the changes to the projects that might be interested
     (have the corresponding native resource in the project contents)"
    shared void fileTreeChanged({NativeResourceChange+} changes) {
        value projectsInModel = ceylonProjects;
        
        for (ceylonProject in projectsInModel) {
            value changesForProject = changes.filter((nativeChange) => 
                                            modelServices.isResourceContainedInProject(nativeChange.resource, ceylonProject));
            if (exists first=changesForProject.first) {
                ceylonProject.projectFileTreeChanged({first, *changesForProject.rest});
            }
        }
    }       
}