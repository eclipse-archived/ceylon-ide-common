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
    IdePhasedUnit
}
import org.eclipse.ceylon.ide.common.util {
    SingleSourceUnitPackage
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

shared abstract class SourceFile(IdePhasedUnit phasedUnit)
        extends CeylonUnit(phasedUnit)
        satisfies Source {
    
    language = Language.ceylon;
    
    shared formal Boolean modifiable;
    
    shared actual Package \ipackage => super.\ipackage;
    
    assign \ipackage {
        value p = \ipackage;
        super.\ipackage = \ipackage;
        if (is SingleSourceUnitPackage p,
            !p.unit exists,
            filename.equals(ModuleManager.packageFile)) {
            if (p.fullPathOfSourceUnitToTypecheck==fullPath) {
                p.unit = this;
            }
        }
    }
    
    shared actual String sourceFileName => filename;
    shared actual String sourceRelativePath => relativePath;
    shared actual String sourceFullPath => fullPath;
    shared actual String ceylonSourceRelativePath => relativePath;
    shared actual String ceylonSourceFullPath => sourceFullPath;
    shared actual String ceylonFileName => filename;
}
