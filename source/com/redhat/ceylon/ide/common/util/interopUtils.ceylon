import ceylon.collection {
    HashMap
}
import ceylon.interop.java {
    JavaList,
    javaString,
    CeylonIterable,
    JavaMap,
    JavaIterable
}

import java.lang {
    JString=String,
    JIterable=Iterable,
    JBoolean=Boolean
}

import java.util.concurrent {
    JCallable=Callable
}

import java.util {
    JList=List,
    JMap=Map
}

shared JList<JString> toJavaStringList({String*} ceylonStringIterable)
        => JavaList(ceylonStringIterable.map((s) => javaString(s)).sequence());

shared JBoolean? toJavaBoolean(Boolean? boolean)
        => if (exists boolean) then JBoolean(boolean) else null;

shared Boolean? toCeylonBoolean(JBoolean? boolean)
        => boolean?.booleanValue();

shared String? toCeylonString(JString? string)
        => string?.string;

shared JString? toJavaString(String? string)
        => if (exists string) then javaString(string) else null;

shared Map<String, String> toCeylonStringMap(JMap<out Object, out Object> javaObjectMap, String(Object) toString = Object.string) => 
        HashMap { 
            *CeylonIterable(javaObjectMap
                    .entrySet())
                    .map((entry)=>toString(entry.key)->toString(entry.\ivalue))
        };
        
shared JMap<JString, JString> toJavaStringMap(Map<String, String> ceylonStringMap) =>
        JavaMap(
            HashMap { 
                *ceylonStringMap.map(
                    (entry) => javaString(entry.key)->javaString(entry.item))
            }
        );

shared JList<Type> toJavaList<Type>({Type*} ceylonIterable) =>
            JavaList(ceylonIterable.sequence());

shared JIterable<Type> toJavaIterable<Type>({Type*} ceylonIterable) =>
        JavaIterable(ceylonIterable);

shared JCallable<T> toCallable<T>(T() fun) =>
        object satisfies JCallable<T> {
            call = fun; 
        };
        