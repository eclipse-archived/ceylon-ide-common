/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.loader.mirror {
    MethodMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    FunctionOrValue
}
import java.util {
    Collections
}
import java.lang {
    JString=String
}

shared abstract class AbstractMethodMirror(shared FunctionOrValue decl)
        satisfies MethodMirror & DeclarationMirror {
    
    declaration => decl;
    
    abstract => decl.abstraction;
    
    default => decl.default;
    
    defaultAccess => !decl.shared;
    
    enclosingClass => null;
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    protected => false;
    
    public => decl.shared;
    
    shared actual default Boolean static => decl.static;
    
    staticInit => false;
}