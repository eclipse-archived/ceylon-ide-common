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
    Value
}

import java.util {
    Collections
}

shared class JGetterMirror(Value decl)
        extends AbstractMethodMirror(decl) {
    
    constructor => false;
    
    declaredVoid => false;
    
    final => true;
    
    name => "get" + capitalize(decl.name);
    
    parameters
            => Collections.emptyList<VariableMirror>();
    
    returnType => ceylonToJavaMapper.mapType(decl.type);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    String capitalize(String str) {
        return (str.first?.uppercased?.string else "") + str.rest;
    }
    
    defaultMethod => false;
    
}
