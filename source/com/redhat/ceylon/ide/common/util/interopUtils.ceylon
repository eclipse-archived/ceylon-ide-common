import java.lang {
    JString = String
}

import java.util {
    JList = List
}

import ceylon.interop.java {
    JavaList,
    javaString,
    CeylonList
}

shared JList<JString> toJavaStringList(Iterable<String> ceylonStringIterable)
    => JavaList(ceylonStringIterable.map((s) => javaString(s)).sequence());

shared Iterable<String> toCeylonStringIterable(JList<JString> javaStringList)
    => CeylonList(javaStringList).map((s) => s.string);
