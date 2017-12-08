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
    TypecheckerAliases,
    ModifiablePhasedUnit
}
shared abstract class ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        (ModifiablePhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> modifiablePhasedUnit)
        extends SourceFile(modifiablePhasedUnit)
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    modifiable => true;
    
    shared actual formal ModifiablePhasedUnitAlias? phasedUnit;

}

shared alias AnyModifiableSourceFile 
        => ModifiableSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;