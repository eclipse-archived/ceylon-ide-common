import ceylon.interop.java {
    JavaList,
    javaString,
    CeylonCollection
}

import java.lang {
    JString=String,
    JBoolean=Boolean
}
import java.util {
    JList=List,
    JCollection=Collection
}

shared JList<JString> toJavaStringList(Iterable<String> ceylonStringIterable)
        => JavaList(ceylonStringIterable.map((s) => javaString(s)).sequence());

shared Iterable<String> toCeylonStringIterable(JCollection<JString> javaStringList)
        => CeylonCollection(javaStringList).map((s) => s.string);

shared JBoolean? toJavaBoolean(Boolean? boolean)
        => if (exists boolean) then JBoolean(boolean) else null;

shared Boolean? toCeylonBoolean(JBoolean? boolean)
        => boolean?.booleanValue() else null;

shared String? toCeylonString(JString? string)
        => string?.string else null;

shared JString? toJavaString(String? string)
        => if (exists string) then javaString(string) else null;
