/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    HashMap,
    HashSet,
    unlinked
}
import ceylon.interop.java {
    CeylonIterator
}

import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.ide.common.platform {
    ModelServicesConsumer,
    VfsServicesConsumer
}
import org.eclipse.ceylon.ide.common.vfs {
    VfsAliases,
    VirtualFileSystem
}
import org.eclipse.ceylon.model.typechecker.context {
    TypeCache
}

import java.lang {
    InterruptedException,
    JBoolean=Boolean
}
import java.util {
    JList=List,
    Arrays
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    Lock
}

import org.jgrapht {
    EdgeFactory
}
import org.jgrapht.experimental.dag {
    DirectedAcyclicGraph
}

shared abstract class BaseCeylonProjects() {}

shared T withCeylonModelCaching<T>(T() do) {
    JBoolean? was = TypeCache.setEnabled(JBoolean.true);
    try {
        return do();
    } finally {
        TypeCache.setEnabled(was);
    }
}

shared abstract class CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProjects()
        satisfies ModelListenerDispatcher<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    value _modelListeners = HashSet<ModelListenerAlias>(unlinked);
    value projectMap = HashMap<NativeProject, CeylonProjectAlias>();
    value lock = ReentrantReadWriteLock(true);

    shared VirtualFileSystem vfs = VirtualFileSystem();

    TypeCache.setEnabledByDefault(false);

    shared actual {ModelListenerAlias*} modelListeners => _modelListeners;
    
    shared void addModelListener(ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile> listener) =>
            _modelListeners.add(listener);
    
    shared void removeModelListener(ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile> listener) =>
            _modelListeners.remove(listener);

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

    shared Integer ceylonProjectNumber
            => withLocking {
        write=false;
        do() => projectMap.size;
        interrupted() => 0;
    };
    
    shared {CeylonProjectAlias*} ceylonProjects
        => withLocking {
            write=false;
            do() => projectMap.items.sequence();
            interrupted() => {};
        };
    
    shared JList<CeylonProjectAlias> ceylonProjectsAsJavaList
        => Arrays.asList(*ceylonProjects);
    
    shared {NativeProject*} nativeProjects
            => withLocking {
        write=false;
        do() => projectMap.keys.sequence();
        interrupted() => {};
    };
    
    shared JList<NativeProject> nativeProjectsAsJavaList
            => Arrays.asList(*nativeProjects);
    
    shared CeylonProjectAlias? getProject(NativeProject? nativeProject)
        => withLocking {
            write=false;
            do() => if (exists nativeProject) then projectMap[nativeProject] else null;
            interrupted() => null;
        };

    shared Boolean removeProject(NativeProject nativeProject) {
        if (exists existingCeylonProject = withLocking {
            write=true;
            function do() => 
                projectMap.remove(nativeProject);

            function interrupted() {
                throw InterruptedException();
            }
        }) {
            ceylonProjectRemoved(existingCeylonProject);
            return true;
        } else {
            return false;
        }
    }

    shared Boolean addProject(NativeProject nativeProject) {
        if (exists newCeylonProject = withLocking {
            write=true;
            function do() {
                 if (projectMap[nativeProject] exists) {
                     return null;
                 } else {
                     value newProject = newNativeProject(nativeProject);
                     projectMap[nativeProject] = newProject;
                     return newProject;
                 }
            }
            function interrupted() {
                 throw InterruptedException();
            }
        }) {
            ceylonProjectAdded(newCeylonProject);
            return true;
        } else {
            return false;
        }
    }

    shared void clearProjects() {
        value projects = withLocking {
            write=true;
            function do() {
                value projects = projectMap.items.sequence();
                projectMap.clear();
                return projects;
            }
            function interrupted() {
                throw InterruptedException();
            }
        };
        projects.each(ceylonProjectRemoved);
    }

    shared {PhasedUnit*} parsedUnits
        => ceylonProjects.flatMap((ceylonProject) => ceylonProject.parsedUnits);
    
    "Dispatch the changes to the projects that might be interested
     (have the corresponding native resource in the project contents)"
    shared void fileTreeChanged({NativeResourceChange*} changes) {
        value projectsInModel = ceylonProjects;
        
        for (ceylonProject in projectsInModel) {
            value changesForProject = changes.filter((nativeChange) => 
                                            modelServices.isResourceContainedInProject(nativeChange.resource, ceylonProject));
            if (exists first=changesForProject.first) {
                ceylonProject.projectFileTreeChanged({first, *changesForProject.rest});
            }
        }
    }
    
    shared {CeylonProjectAlias*} ceylonProjectsInTopologicalOrder {
       value theCeylonProjects = ceylonProjects.sequence();
       class Dependency(shared CeylonProjectAlias requiring, shared CeylonProjectAlias required) {}
       value dag = DirectedAcyclicGraph<CeylonProjectAlias, Dependency>(
            object satisfies EdgeFactory<CeylonProjectAlias, Dependency> {
               createEdge(CeylonProjectAlias sourceVertex, CeylonProjectAlias targetVertex) =>
                       Dependency(sourceVertex, targetVertex);
           }
       );
       for (ceylonProject in theCeylonProjects) {
           dag.addVertex(ceylonProject);
       }
       
       for (ceylonProject in theCeylonProjects) {
           for (required in ceylonProject.referencedCeylonProjects) {
               dag.addDagEdge(ceylonProject, required); 
           }
           for (requiring in ceylonProject.referencingCeylonProjects) {
               dag.addDagEdge(requiring, ceylonProject); 
           }
       }
       return object satisfies {CeylonProjectAlias*} {
           iterator() => CeylonIterator(dag.iterator());
       };
    }
}