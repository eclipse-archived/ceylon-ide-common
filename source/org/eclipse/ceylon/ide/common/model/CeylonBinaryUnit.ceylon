/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.model {
    CeylonUnit
}
import org.eclipse.ceylon.ide.common.typechecker {
    ExternalPhasedUnit
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}

shared alias AnyCeylonBinaryUnit => CeylonBinaryUnit<out Anything,out Anything,out Anything>;

shared abstract class CeylonBinaryUnit<NativeProject, JavaClassRoot, JavaElement>
        (shared actual JavaClassRoot typeRoot, 
        String theFilename, String theRelativePath, String theFullPath, 
        Package thePackage)
        extends CeylonUnit.init(theFilename, theRelativePath, theFullPath, thePackage)
        satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement>
                & BinaryWithSources {
    
    shared actual default ExternalPhasedUnit? phasedUnit {
        assert (is ExternalPhasedUnit? phasedUnit = super.phasedUnit);
        return phasedUnit;
    }
    
    shared actual ExternalPhasedUnit? findPhasedUnit() {
        try {
            if (exists artifact = ceylonModule.artifact) {
                value binaryUnitRelativePath 
                        = fullPath.replace(artifact.path + "!/", "");
                value sourceUnitRelativePath 
                        = ceylonModule.toSourceUnitRelativePath(
                                binaryUnitRelativePath);
                if (exists sourceUnitRelativePath) {
                    return ceylonModule.getPhasedUnitFromRelativePath(
                                sourceUnitRelativePath);
                }
            }
        } catch (e) {
            e.printStackTrace();
        }
        return null;
    }
    
    ceylonSourceRelativePath 
            => ceylonModule.getCeylonDeclarationFile(
                    sourceRelativePath);
    ceylonSourceFullPath 
            => computeFullPath(ceylonSourceRelativePath);
    ceylonFileName 
            => if (exists crp = ceylonSourceRelativePath,
                    !crp.empty)
            then crp.split('/'.equals).last
            else null;
    
    binaryRelativePath => relativePath;
    
    sourceFileName 
            => (super of BinaryWithSources)
                .sourceFileName;
    sourceFullPath 
            => (super of BinaryWithSources)
                .sourceFullPath;
    sourceRelativePath 
            => (super of BinaryWithSources)
                .sourceRelativePath;
}
