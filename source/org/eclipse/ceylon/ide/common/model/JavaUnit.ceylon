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
    BaseIdeModule,
    IResourceAware,
    IdeUnit
}
import org.eclipse.ceylon.model.loader.model {
    LazyPackage
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit
}

shared interface JavaUnitUtils<NativeFolder,NativeFile,JavaClassRoot> {
    shared formal NativeFile? javaClassRootToNativeFile(JavaClassRoot javaClassRoot);
    shared formal NativeFolder? javaClassRootToNativeRootFolder(JavaClassRoot javaClassRoot);
}

shared alias AnyJavaUnit => JavaUnit<out Anything,out Anything,out Anything,out Anything,out Anything>;

shared abstract class JavaUnit<NativeProject,NativeFolder,NativeFile,JavaClassRoot,JavaElement>
        (String theFilename, String theRelativePath, String theFullPath, LazyPackage thePackage)
        extends IdeUnit.init(theFilename, theRelativePath, theFullPath, thePackage)
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
                & IJavaModelAware<NativeProject, JavaClassRoot, JavaElement>
                & JavaUnitUtils<NativeFolder, NativeFile, JavaClassRoot> {
    
    shared void remove() {
        value p = \ipackage;
        p.removeUnit(this);
        assert (is BaseIdeModule m = p.\imodule);
        m.moduleInReferencingProjects
                .each((m) => m.removedOriginalUnit(relativePath));
    }
    
    shared formal Unit clone();
    
    shared void update() {
        remove();
        value newUnit = clone();
        newUnit.dependentsOf.addAll(dependentsOf);
        thePackage.addLazyUnit(newUnit);
    }

    resourceFile => javaClassRootToNativeFile(typeRoot);
    resourceProject => project;
    resourceRootFolder 
            => if (resourceFile exists) 
            then javaClassRootToNativeRootFolder(typeRoot)
            else null;
}
