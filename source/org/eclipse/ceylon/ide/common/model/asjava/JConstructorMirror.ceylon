/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    Class,
    ParameterList
}

import java.util {
    List,
    Collections,
    ArrayList
}
import java.lang {
    JString=String
}

class JConstructorMirror(Class cls, ParameterList pl)
        satisfies MethodMirror & DeclarationMirror {
    
    declaration => cls;
    
    abstract => false;
    
    constructor => true;
    
    declaredVoid => false;
    
    default => false;
    
    defaultAccess => !cls.shared;
    
    defaultMethod => false;
    
    enclosingClass => null;
    
    final => false;
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    name => cls.name;
    
    shared actual List<VariableMirror> parameters {
        value vars = ArrayList<VariableMirror>();
        for (p in pl.parameters) {
            vars.add(JVariableMirror(p));
        }
        return vars;
    }
    
    protected => false;
    
    public => cls.shared;
    
    returnType => null; // TODO I think
    
    static => false;
    
    staticInit => false;
    
    typeParameters => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
}