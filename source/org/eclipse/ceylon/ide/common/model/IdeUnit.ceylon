/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit 
        extends TypecheckerUnit
        satisfies IUnit & SourceAware  {
    
    shared new(BaseIdeModuleSourceMapper? moduleSourceMapper) 
            extends TypecheckerUnit(moduleSourceMapper) {}

    shared new init(String theFilename, 
                    String theRelativePath, 
                    String theFullPath, 
                    Package thePackage) 
            extends TypecheckerUnit(theFilename, 
                                    theRelativePath, 
                                    theFullPath, 
                                    thePackage) {}
    
    shared actual BaseIdeModule ceylonModule {
        assert (is BaseIdeModule ideModule = \ipackage.\imodule);
        return ideModule;
    }
    
    shared actual Package ceylonPackage 
            => \ipackage;

    shared actual Package? javaLangPackage 
            => ceylonModule.ceylonProject
                ?.modules?.javaLangPackage 
                else super.javaLangPackage;
    assign javaLangPackage
            => super.javaLangPackage = javaLangPackage;
    
    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
