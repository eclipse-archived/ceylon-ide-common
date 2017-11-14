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

shared abstract class JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
            typeRoot, 
            String filename,
            String relativePath,
            String fullPath,
            LazyPackage pkg)
        extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(filename, relativePath, fullPath, pkg)
        satisfies Source
        & JavaModelServicesConsumer<JavaClassRoot> {
    language = Language.java;
    
    shared actual default Unit clone() 
            => javaModelServices.newJavaCompilationUnit(typeRoot, relativePath, filename, fullPath, pkg);
    
    shared actual JavaClassRoot typeRoot;
    
    shared actual String sourceFileName =>
            filename;
    shared actual String sourceRelativePath =>
            relativePath;
    shared actual String sourceFullPath => 
            fullPath;
}
