package com.redhat.ceylon.ide.common.util;

import com.redhat.ceylon.compiler.java.metadata.Ceylon;
import com.redhat.ceylon.compiler.java.metadata.Ignore;
import com.redhat.ceylon.compiler.java.metadata.Method;
import com.redhat.ceylon.compiler.java.metadata.Name;
import com.redhat.ceylon.compiler.java.metadata.TypeInfo;
import com.redhat.ceylon.compiler.java.metadata.TypeParameter;
import com.redhat.ceylon.compiler.java.metadata.TypeParameters;
import com.redhat.ceylon.compiler.java.runtime.model.TypeDescriptor;

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