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
    TypeParameterMirror,
    VariableMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    Function
}

import java.util {
    List,
    Collections,
    ArrayList
}

shared class JMethodMirror(Function decl, Boolean forceStatic = false)
        extends AbstractMethodMirror(decl) {
    
    constructor => false;
    
    declaredVoid => decl.declaredVoid;
    
    final => true;
    
    name => decl.name;
    
    shared actual List<VariableMirror> parameters {
        value vars = ArrayList<VariableMirror>();
        for (p in decl.firstParameterList.parameters) {
            vars.add(JVariableMirror(p));
        }
        return vars;
    }
    
    returnType => ceylonToJavaMapper.mapType(decl.type);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => decl.variable;
    
    defaultMethod => false;
    
    static => forceStatic then true else super.static;
}
