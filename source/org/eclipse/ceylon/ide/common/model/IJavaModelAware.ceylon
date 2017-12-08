/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.util {
    BaseProgressMonitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration
}
shared interface IJavaModelAware<NativeProject,JavaClassRoot,JavaElement> satisfies IProjectAware<NativeProject> {
    shared formal JavaClassRoot typeRoot;
    shared formal JavaElement? toJavaElement(Declaration ceylonDeclaration, BaseProgressMonitor? monitor = null);
    shared formal NativeProject javaClassRootToNativeProject(JavaClassRoot javaClassRoot);
    shared actual NativeProject? project => 
            javaClassRootToNativeProject(typeRoot);
}