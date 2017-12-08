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
    CrossProjectPhasedUnit,
    TypecheckerAliases
}
import org.eclipse.ceylon.ide.common.util {
    unsafeCast
}

shared class CrossProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        (CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> crossProjectPhasedUnit) 
        extends ExternalSourceFile(crossProjectPhasedUnit)
        satisfies ICrossProjectCeylonReference<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    resourceProject 
            => if (exists ppu = phasedUnit?.originalProjectPhasedUnit)
            then ppu.resourceProject else null;
    
    resourceRootFolder 
            => if (exists ppu = phasedUnit?.originalProjectPhasedUnit)
            then ppu.resourceRootFolder else null;
    
    resourceFile 
            => if (exists ppu = phasedUnit?.originalProjectPhasedUnit)
            then ppu.resourceFile else null;
    
    //TODO: get rid of unsafeCast()
    shared actual CrossProjectPhasedUnitAlias? phasedUnit
            => unsafeCast<CrossProjectPhasedUnitAlias?>(super.phasedUnit);
    
    originalSourceFile => originalPhasedUnit?.unit;
    
    originalPhasedUnit => phasedUnit?.originalProjectPhasedUnit;
    
}
