import com.redhat.ceylon.model.loader.mirror {
    VariableMirror,
    FieldMirror,
    TypeKind,
    TypeParameterMirror,
    AnnotationMirror,
    ClassMirror,
    MethodMirror,
    TypeMirror
}
import ceylon.test {
    assertEquals,
    fail
}
import ceylon.collection {
    MutableList,
    HashSet
}
String indent = "  ";

String dumpClassMirror(ClassMirror cm, HashSet<MirrorKey> alreadyDumped, String prefix="") => if (!alreadyDumped.add(MirrorKey(cm)))
then cm.qualifiedName
else let(nextLevelPrefix = prefix + indent + indent)
"\n".join({
    "class `` cm.qualifiedName `` {",
    "\n".join({
        "public = `` cm.public ``",
        "protected = `` cm.protected ``",
        "defaultAccess = `` cm.defaultAccess ``",
        "static = `` cm.static``",
        "final = `` cm.final``",
        "enum = `` cm.enum``",
        "abstract = `` cm.abstract ``",
        "annotationType = `` cm.annotationType ``",
        "anonymous = `` cm.anonymous ``",
        "interface = `` cm.\iinterface``",
        "innerClass = `` cm.innerClass``",
        "localClass = `` cm.localClass``",
        "ceylonToplevelAttribute = `` cm.ceylonToplevelAttribute ``",
        "ceylonToplevelMethod = `` cm.ceylonToplevelMethod ``",
        "ceylonToplevelObject = `` cm.ceylonToplevelObject ``",
        "javaSource = `` cm.javaSource``",
        "loadedFromSource = `` cm.loadedFromSource``",
        "name = `` cm.name ``",
        "flatName = `` cm.flatName``",
        "package = `` cm.\ipackage?.qualifiedName else "<null>" ``",
        
        "enclosingClass = `` if (exists ec = cm.enclosingClass)
        then "\n`` dumpClassMirror(ec, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "enclosingMethod = `` if (exists em = cm.enclosingMethod)
        then "\n`` dumpMethodMirror(em, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "superclass = `` if (exists sc = cm.superclass)
        then "\n`` dumpTypeMirror(sc, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "directInnerClasses = [
         `` "\n".join({ 
            for (ic in cm.directInnerClasses)
            dumpClassMirror(ic, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "directFields = [
         `` "\n".join({ 
            for (df in cm.directFields)
            dumpFieldMirror(df, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "directMethods = [
         `` "\n".join({ 
            for (dm in cm.directMethods)
            dumpMethodMirror(dm, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "typeParameters = [
         `` "\n".join({ 
            for (tp in cm.typeParameters)
            dumpTypeParameterMirror(tp, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "interfaces = [
         `` "\n".join({ 
            for (itf in cm.interfaces)
            dumpTypeMirror(itf, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "annotations = [
         `` "\n".join({ 
            for (an in cm.annotationNames)
            dumpAnnotationMirror(an.string, cm.getAnnotation(an.string), alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence());

String dumpMethodMirror(MethodMirror mm, HashSet<MirrorKey> alreadyDumped, String prefix="") =>
        let(nextLevelPrefix = prefix + "  ")
"\n".join({
    "method `` mm.name else "<null>" `` {",
    "\n".join({
        "public = `` mm.public ``",
        "protected = `` mm.protected ``",
        "final = `` mm.final ``",
        "static = `` mm.static ``",
        "abstract = `` mm.abstract ``",
        "variadic = `` mm.variadic ``",
        "default = `` if (mm.constructor) then false else mm.default ``",
        "constructor = `` mm.constructor ``",
        "staticInit = `` mm.staticInit ``",
        "declaredVoid = `` mm.declaredVoid ``",
        "defaultAccess = `` mm.defaultAccess ``",
        "defaultMethod = `` mm.defaultMethod ``",
        "enclosingClass = `` if (exists ec = mm.enclosingClass)
        then "\n`` dumpClassMirror(ec, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        "parameters = `` mm.parameters ``",
        "returnType = `` if (exists rt = mm.returnType)
        then "\n`` dumpTypeMirror(rt, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        "typeParameters = [
         `` "\n".join({ 
            for (tp in mm.typeParameters)
            dumpTypeParameterMirror(tp, alreadyDumped, nextLevelPrefix)
        }) ``
         ]",
        "annotations = [
         `` "\n".join({ 
            for (an in mm.annotationNames)
            dumpAnnotationMirror(an.string, mm.getAnnotation(an.string), alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence());

String dumpAnnotationMirror(String annotationName, AnnotationMirror? am, HashSet<MirrorKey> alreadyDumped, String prefix="") => let(nextLevelPrefix = prefix + "  ")
"\n".join({
    "annotation `` annotationName `` {",
    if (exists am)
    then "\n".join({
        
    }.map((String l) => indent + l))
    else "<null>",
    "}"
}.map((l) => prefix + l).sequence());


String dumpFieldMirror(FieldMirror fm, HashSet<MirrorKey> alreadyDumped, String prefix="") =>
        let(nextLevelPrefix = prefix + "  ")
"\n".join({
    "field `` fm.name else "<null>" `` {",
    "\n".join({
        "public = `` fm.public ``",
        "protected = `` fm.protected ``",
        "final = `` fm.final ``",
        "abstract = `` fm.static ``",
        "defaultAccess = `` fm.defaultAccess ``",
        "type = `` if (exists t = fm.type)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        "annotations = [
         `` "\n".join({ 
            for (an in fm.annotationNames)
            dumpAnnotationMirror(an.string, fm.getAnnotation(an.string), alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence());


String dumpVariableMirror(VariableMirror vm, HashSet<MirrorKey> alreadyDumped, String prefix="") =>
        let(nextLevelPrefix = prefix + "  ")
"\n".join({
    "variable `` vm.name else "<null>" `` {",
    "\n".join({
        "type = `` if (exists t = vm.type)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        "annotations = [
         `` "\n".join({ 
            for (an in vm.annotationNames)
            dumpAnnotationMirror(an.string, vm.getAnnotation(an.string), alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence());


String dumpTypeParameterMirror(TypeParameterMirror tpm, HashSet<MirrorKey> alreadyDumped, String prefix="")  =>
        let(nextLevelPrefix = prefix + "  ")
"\n".join({
    "type parameter `` tpm.name else "<null>" `` {",
    "\n".join({
        "bounds = [
         `` "\n".join({ 
            for (b in tpm.bounds)
            dumpTypeMirror(b, alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence());

String dumpTypeMirror(TypeMirror cm, HashSet<MirrorKey> alreadyDumped, String prefix="") => 
        if (exists kind = typeKind(cm)) 
then if (!kind.primitive && !alreadyDumped.add(MirrorKey(cm)))
then cm.string
else let(nextLevelPrefix = prefix + indent + indent)
"\n".join({
    "type `` cm.string `` {",
    "\n".join({
        "primitive = `` cm.primitive ``",
        "raw = `` cm.raw ``",
        "kind = `` cm.kind.name()``",
        "qualifiedName = `` if (kind == TypeKind.declared || kind == TypeKind.typevar) then cm.qualifiedName else "<no name>"``",
        
        "declaredClass = `` if (exists ec = cm.declaredClass)
        then "\n`` dumpClassMirror(ec, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "lowerBound = `` if (kind == TypeKind.wildcard, exists tpm = cm.typeParameter, exists t = cm.lowerBound)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "upperBound = `` if (kind == TypeKind.wildcard, exists tpm = cm.typeParameter, exists t = cm.upperBound)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "typeParameter = `` if (exists tpm = cm.typeParameter)
        then "\n`` dumpTypeParameterMirror(tpm, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "componentType = `` if (kind == TypeKind.array, exists t = cm.componentType)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "qualifyingType = `` if (exists t = cm.qualifyingType)
        then "\n`` dumpTypeMirror(t, alreadyDumped, nextLevelPrefix) ``"
        else "<null>" ``",
        
        "typeParameters = [
         `` "\n".join({ 
            for (ta in cm.typeArguments)
            dumpTypeMirror(ta, alreadyDumped, nextLevelPrefix)
        }) ``
         ]"
    }.map((l) => indent + l)),
    "}"
}.map((l) => prefix + l).sequence())
else "unesolvedType";

class MirrorKey(ClassMirror | TypeMirror mirror) {
    shared actual String string {
        if (is ClassMirror mirror) {
            return "[Class] `` mirror.qualifiedName ``";
        } else {
            value kind = typeKind(mirror);
            if (! exists kind) {
                return "<unresolved>";
            }
            return mirror.string;
        }
    }
    hash => string.hash;
    equals(Object that) => string==that.string;
}

void compareMirrors(ClassMirror? binaryMirror, ClassMirror? sourceMirror, MutableList<AssertionError> errors) {
    if (! exists binaryMirror) {
        fail("`binaryMirror should not be `null`");
        return;
    }
    if (! exists sourceMirror) {
        fail("`sourceMirror should not be `null`");
        return;
    }
    try {
        value sourceMirrorDesc = dumpClassMirror(sourceMirror, HashSet<MirrorKey>());
        print("sourceMirror Description:");
        print("=========================");
        print(sourceMirrorDesc);
        value binaryMirrorDesc = dumpClassMirror(binaryMirror, HashSet<MirrorKey>());
        print("");
        print("binaryMirror Description:");
        print("=========================");
        print(binaryMirrorDesc);
        
        assertEquals(sourceMirrorDesc, binaryMirrorDesc, "Mirrors differ between generated binaries, and source based mirrors");
    } catch(AssertionError ae) {
        errors.add(ae);
    }
}

