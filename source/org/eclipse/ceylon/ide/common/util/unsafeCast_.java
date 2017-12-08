/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
package org.eclipse.ceylon.ide.common.util;

import org.eclipse.ceylon.compiler.java.metadata.Ceylon;
import org.eclipse.ceylon.compiler.java.metadata.Ignore;
import org.eclipse.ceylon.compiler.java.metadata.Method;
import org.eclipse.ceylon.compiler.java.metadata.Name;
import org.eclipse.ceylon.compiler.java.metadata.TypeInfo;
import org.eclipse.ceylon.compiler.java.metadata.TypeParameter;
import org.eclipse.ceylon.compiler.java.metadata.TypeParameters;
import org.eclipse.ceylon.compiler.java.runtime.model.TypeDescriptor;

@Ceylon(major = 8)
@Method
public final class unsafeCast_ {
    
    private unsafeCast_() {
    }
    
    @SuppressWarnings("unchecked")
    @TypeParameters({@TypeParameter(value="Return")})
    @TypeInfo("Return")
    public static <Return> Return unsafeCast(
            @Ignore TypeDescriptor $reifiedReturn,
            @Name("instance")
            @TypeInfo("ceylon.language::Anything")
            final Object instance) {
        return (Return) instance;
    }
}
