/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.platform {
    JavaModelServicesConsumer
}
import org.eclipse.ceylon.model.loader.model {
    LazyPackage
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit
}

import java.lang.ref {
    WeakReference
}

shared abstract class CrossProjectJavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
            BaseCeylonProject originalProject,
            JavaClassRoot typeRoot, 
            String filename,
            String relativePath,
            String fullPath,
            LazyPackage pkg)
        extends JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(typeRoot, filename, relativePath, fullPath, pkg)
        satisfies ICrossProjectReference<NativeProject, NativeFolder, NativeFile>
        & JavaModelServicesConsumer<JavaClassRoot> {
    
    function findOriginalSourceFile() => 
            let(searchedPackageName = pkg.nameAsString)
    if (exists members=originalProject.modules?.fromProject?.flatMap((m) => { *m.packages })
        ?.find((p) => p.nameAsString == searchedPackageName)
            ?.members)
    then { *members }
            .map((decl) => decl.unit)
            .narrow<JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>>()
            .find((unit) => unit.fullPath == fullPath)
    else null;

    variable value originalUnitReference = WeakReference(findOriginalSourceFile());

    shared actual Unit clone() 
            => javaModelServices.newCrossProjectJavaCompilationUnit(originalProject, typeRoot, relativePath, filename, fullPath, pkg);
    
    shared actual JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>? originalSourceFile {
        if (exists original = 
                originalUnitReference.get()) {
            return original;
        }
        else {
            if (exists theOriginalUnit = findOriginalSourceFile()) {
                originalUnitReference = WeakReference(theOriginalUnit);
                return theOriginalUnit;
            }
        }
        return null;
    }
}
