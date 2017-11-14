/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.util {
    BaseProgressMonitor
}
shared interface BuildHook<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared default void repositoryManagerReset(CeylonProjectAlias ceylonProject) {}
    
    "Returns [[true]] if the analysis has been correctly done by the hook,
     or [[false]] if the hook analysis has been cancelled due to
     critical errors that would make the upcoming build impossible or pointless."
    shared default Boolean analyzingChanges(
        {ChangeToAnalyze*} changes,  
        CeylonProjectBuildAlias build, 
        CeylonProjectBuildAlias.State state) => true;
    
    shared default void beforeClasspathResolution(CeylonProjectBuildAlias build, CeylonProjectBuildAlias.State state) {}
    shared default void afterClasspathResolution(CeylonProjectBuildAlias build, CeylonProjectBuildAlias.State state) {}

    shared default void beforeDependencyTreeValidation(CeylonProjectAlias ceylonProject,
        BaseProgressMonitor.Progress progress) {}
    shared default void afterDependencyTreeValidation(CeylonProjectAlias ceylonProject,
        BaseProgressMonitor.Progress progress) {}
}