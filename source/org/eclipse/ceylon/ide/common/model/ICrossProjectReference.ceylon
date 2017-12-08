/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
}

shared interface ICrossProjectReference<NativeProject, NativeFolder, NativeFile>
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile> {
    shared formal IdeUnit? originalSourceFile;
}

shared interface ICrossProjectCeylonReference<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ICrossProjectReference<NativeProject, NativeFolder, NativeFile> {
    shared actual formal ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>? originalSourceFile;
    shared formal ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? originalPhasedUnit;
}
