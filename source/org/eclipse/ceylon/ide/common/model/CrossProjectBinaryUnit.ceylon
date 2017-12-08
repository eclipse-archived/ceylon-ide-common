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
    TypecheckerAliases
}
import org.eclipse.ceylon.ide.common.util {
    unsafeCast
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}

import java.lang.ref {
    WeakReference
}

shared abstract class CrossProjectBinaryUnit<NativeProject,NativeResource,NativeFolder,NativeFile,JavaClassRoot,JavaElement>
        (JavaClassRoot typeRoot, String fileName, String relativePath, String fullPath, Package thePackage) 
        extends CeylonBinaryUnit<NativeProject,JavaClassRoot,JavaElement>
                (typeRoot, fileName, relativePath, fullPath, thePackage)
        satisfies ICrossProjectCeylonReference<NativeProject,NativeResource,NativeFolder,NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    variable value originalProjectPhasedUnitRef 
            = WeakReference<ProjectPhasedUnitAlias>(null);
    
    //TODO: Get rid of this unsafeCast()!
    shared actual CrossProjectPhasedUnitAlias? phasedUnit 
            => unsafeCast<CrossProjectPhasedUnitAlias?>
                    (super.phasedUnit);
    
    originalSourceFile => originalPhasedUnit?.unit;
    
    resourceProject 
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceProject;
    resourceRootFolder 
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceRootFolder;
    
    resourceFile
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceFile;
    
    shared actual ProjectPhasedUnitAlias? originalPhasedUnit {
        if (exists original 
                = originalProjectPhasedUnitRef.get()) {
            return original;
        }
        else {
            if (exists originalProject = ceylonModule.originalProject,
                exists originalTypeChecker = originalProject.typechecker,
                exists phasedUnit = 
                    originalTypeChecker.getPhasedUnitFromRelativePath(
                        ceylonModule.toSourceUnitRelativePath(relativePath))) {
                assert (is ProjectPhasedUnitAlias phasedUnit);
                originalProjectPhasedUnitRef = WeakReference(phasedUnit);
                return phasedUnit;
            }
        }
        return null;
    }
}
