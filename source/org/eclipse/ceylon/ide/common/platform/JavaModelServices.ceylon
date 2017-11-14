/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.model {
    BaseCeylonProject
}
import org.eclipse.ceylon.model.loader.mirror {
    ClassMirror
}
import org.eclipse.ceylon.model.loader.model {
    LazyPackage
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit
}
shared interface JavaModelServices<JavaClassRoot> {
    shared formal JavaClassRoot? getJavaClassRoot(ClassMirror classMirror);
    shared formal Unit newCrossProjectJavaCompilationUnit(BaseCeylonProject ceylonProject, JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newCrossProjectBinaryUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newJavaCompilationUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newCeylonBinaryUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newJavaClassFile(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
}