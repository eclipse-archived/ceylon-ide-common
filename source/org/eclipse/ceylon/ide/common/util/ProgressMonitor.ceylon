/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.typechecker.model {
    Cancellable
}

shared interface BaseProgressMonitor satisfies Cancellable {
    shared formal class Progress(Integer estimatedWork, String? taskName)
            satisfies Destroyable & Cancellable {
        shared formal void changeTaskName(String taskDescription);
        shared formal void updateRemainingWork(Integer remainingWork);
        shared formal void subTask(String subTaskDescription);
        shared formal void worked(Integer amountOfWork);
        shared formal BaseProgressMonitorChild newChild(Integer allocatedWork);
        shared Anything() work(Integer amountOfWork, void action()) => () {
            action();
            worked(amountOfWork);
        };
        shared void iterate<Element>(Integer work, Anything on(Element item))({Element*} iterable) {
            iterable.each((e) {
                on(e);
                worked(work);
            });
        }
    }
}

shared interface BaseProgressMonitorChild 
        satisfies BaseProgressMonitor {
}

shared sealed interface Wrapper<out Wrapped> {
    shared formal Wrapped wrapped;
}

shared interface ProgressMonitor<NativeMonitor>
        satisfies BaseProgressMonitor {
    shared formal actual class Progress(Integer estimatedWork, String? taskName) 
            extends super.Progress(estimatedWork, taskName)
            satisfies Wrapper<NativeMonitor> {
        shared formal actual ProgressMonitorChild<NativeMonitor> newChild(Integer allocatedWork);
    }
}

shared interface ProgressMonitorChild<NativeMonitor>
        satisfies ProgressMonitor<NativeMonitor> 
        & Wrapper<NativeMonitor>
        & BaseProgressMonitorChild {
}

shared abstract class ProgressMonitorImpl<NativeMonitor> 
         satisfies ProgressMonitorChild<NativeMonitor> {
    late String? parentTaskName;
    variable String? taskName_=null;
    
    shared default String? taskName => taskName_;
    assign taskName {
        taskName_ = taskName;
    }

    shared new child(ProgressMonitorImpl<NativeMonitor> parent, Integer allocatedWork) {
        parentTaskName = parent.taskName;
        taskName_ = parentTaskName;
    }
    
    shared new wrap(NativeMonitor? monitor) {
        parentTaskName = null;
    }
    
    shared default void initialze(Integer estimatedWork, String? taskName) {
        updateRemainingWork(estimatedWork);
        if (exists taskName) {
            this.taskName = taskName; 
        }
    }
    shared formal void updateRemainingWork(Integer remainingWork);
    shared formal void subTask(String subTaskDescription);
    shared formal void worked(Integer amount);
    shared formal ProgressMonitorChild<NativeMonitor> newChild(Integer allocatedWork);
    shared default void done() {
        if (exists parentTaskName,
            exists currentTaskName=taskName,
            parentTaskName != currentTaskName) {
            taskName = parentTaskName;
        }
    }
    
    shared default actual class Progress(Integer estimatedWork, String? taskName)
            extends super.Progress(estimatedWork, taskName) {
        outer.initialze(estimatedWork, taskName);
        
        shared actual void changeTaskName(String taskDescription) =>
                outer.taskName = taskDescription;
        shared actual void updateRemainingWork(Integer remainingWork) => 
                outer.updateRemainingWork(remainingWork);
        shared actual void subTask(String subTaskDescription) =>
                outer.subTask(subTaskDescription);
        shared actual void worked(Integer amount) =>
                outer.worked(amount);
        shared default actual ProgressMonitorChild<NativeMonitor> newChild(Integer allocatedWork) =>
                outer.newChild(allocatedWork);
        shared actual void destroy(Throwable? error) {
            outer.done();
            if (exists error) {
                throw error;
            }
        }
        shared actual Boolean cancelled => outer.cancelled;
        shared default actual NativeMonitor wrapped => outer.wrapped;
    }
}
