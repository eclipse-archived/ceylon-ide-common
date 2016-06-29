import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    TypeParameterMirror,
    FieldMirror,
    PackageMirror,
    TypeMirror,
    MethodMirror,
    AnnotationMirror,
    TypeKind
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

import java.util {
    Collections
}
import java.lang {
    JString=String
}

shared object unknownClassMirror satisfies ClassMirror {
    
    abstract => false;
    
    annotationType => false;
    
    anonymous => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => false;
    
    defaultAccess => false;
    
    directFields => Collections.emptyList<FieldMirror>();
    
    directInnerClasses => Collections.emptyList<ClassMirror>();
    
    directMethods => Collections.emptyList<MethodMirror>();
    
    shared actual ClassMirror? enclosingClass => null;
    
    shared actual MethodMirror? enclosingMethod => null;
    
    enum => false;
    
    final => false;

    name => "unknown";
    
    flatName => name;
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    shared actual String? getCacheKey(Module? \imodule) => null;
    
    innerClass => false;
    
    \iinterface => false;
    
    interfaces => Collections.emptyList<TypeMirror>();
    
    javaSource => false;
    
    loadedFromSource => false;
    
    localClass => false;
    
    shared actual PackageMirror \ipackage = object satisfies PackageMirror {
        qualifiedName => "";
    };
    
    protected => false;
    
    public => false;
    
    qualifiedName => name;
    
    static => false;
    
    shared actual Null superclass => null;
    
    typeParameters => Collections.emptyList<TypeParameterMirror>();
}

shared class UnknownTypeMirror(shared actual String qualifiedName = "unknown")
        satisfies TypeMirror {
    
    shared actual TypeMirror? componentType => null;
    
    declaredClass => unknownClassMirror;
    
    kind => TypeKind.\iDECLARED;
    
    shared actual TypeMirror? lowerBound => null;
    
    primitive => false;
    
    shared actual TypeMirror? qualifyingType => null;
    
    raw => false;
    
    typeArguments => Collections.emptyList<TypeMirror>();
    
    shared actual TypeParameterMirror? typeParameter => null;
    
    shared actual TypeMirror? upperBound => null;
}