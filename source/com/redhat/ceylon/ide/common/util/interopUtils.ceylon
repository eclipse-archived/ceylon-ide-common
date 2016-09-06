import ceylon.collection {
    HashMap
}
import ceylon.interop.java {
    javaString,
    JavaMap
}

import java.lang {
    JString=String
}
import java.util {
    JList=List,
    JMap=Map,
    Arrays
}

shared JList<JString> toJavaStringList({String*} ceylonStringIterable)
        => Arrays.asList(*ceylonStringIterable.map(javaString));

shared Map<String, String> toCeylonStringMap(javaObjectMap, toString = Object.string) {
    String(Object) toString;
    JMap<out Object, out Object> javaObjectMap;
    return HashMap {
        for (entry in javaObjectMap.entrySet())
        toString(entry.key) -> toString(entry.\ivalue)
    };
}

shared JMap<JString, JString> toJavaStringMap(ceylonStringMap) {
    Map<String, String> ceylonStringMap;
    return JavaMap(HashMap {
        for (entry in ceylonStringMap)
        javaString(entry.key)->javaString(entry.item)
    });
}
