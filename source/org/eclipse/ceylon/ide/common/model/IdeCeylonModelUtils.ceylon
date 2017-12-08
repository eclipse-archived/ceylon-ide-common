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
    Declaration,
    Unit
}

import org.eclipse.ceylon.ide.common.util {
    SingleSourceUnitPackage
}

shared Boolean isCentralModelDeclaration(Declaration? declaration) => 
        if (exists declaration) 
        then isCentralModelUnit(declaration.unit)
        else true;

shared Boolean isCentralModelUnit(Unit? unit) => 
        if (is CeylonUnit unit) 
        then 
            if (unit is ProjectSourceFile<out Object, out Object, out Object, out Object>) 
            then true 
            else ! (unit.\ipackage is SingleSourceUnitPackage)
        else true;
