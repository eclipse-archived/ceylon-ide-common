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
    EditedPhasedUnit,
    TypecheckerAliases
}
import java.lang.ref {
    WeakReference
}

shared class EditedSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        (EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> editedPhasedUnit)
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
                (editedPhasedUnit)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    value editedPhasedUnitRef = WeakReference(editedPhasedUnit);
    
    shared actual EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? phasedUnit
            => editedPhasedUnitRef.get();
    
    shared ProjectSourceFileAlias? originalSourceFile 
            => phasedUnit?.originalPhasedUnit?.unit;
    
    resourceProject => phasedUnit?.resourceProject;
    resourceFile => phasedUnit?.resourceFile;
    resourceRootFolder => phasedUnit?.resourceRootFolder;
    
}

