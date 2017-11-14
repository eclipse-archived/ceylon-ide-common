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
    MethodMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    Function
}

import java.util {
    List,
    Collections
}

shared class JToplevelFunctionMirror(Function decl)
        extends AbstractClassMirror(decl) {

    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => true;
    
    ceylonToplevelObject => false;
    
    satisfiedTypes => Collections.emptyList<Type>();
    
    supertype => null;
    
    name => super.name + "_";
    
    scanExtraMembers(List<MethodMirror> methods)
            => methods.add(JMethodMirror(decl, true));
}
