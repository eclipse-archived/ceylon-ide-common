package com.redhat.ceylon.ide.common.util;

import java.util.ArrayList;
import java.util.List;

import ceylon.interop.java.JavaIterable;

public class InteropUtils {
    public static List<String> toJavaStringList(ceylon.language.Iterable<? extends ceylon.language.String, ?> ceylonStringIterable) {
        List<String> javaStringList = new ArrayList<>((int) ceylonStringIterable.getSize()); 
        for (ceylon.language.String s : new JavaIterable<ceylon.language.String>(ceylon.language.String.$TypeDescriptor$, ceylonStringIterable)) {
            javaStringList.add(s.value);
        }
        return javaStringList;
    }
}
