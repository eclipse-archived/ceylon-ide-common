import ceylon.interop.java {
    javaClass,
    CeylonIterable
}

import com.redhat.ceylon.model.loader.impl.reflect.mirror {
    ReflectionType
}
import com.redhat.ceylon.model.loader.mirror {
    TypeMirror,
    TypeParameterMirror,
    ClassMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ClassOrInterface
}

import java.lang {
    JString=String,
    Class
}
import java.util {
    List,
    Collections,
    ArrayList
}

import javax.lang.model.type {
    TypeKind
}

TypeMirror longMirror = PrimitiveMirror(TypeKind.\iLONG, "long");

TypeMirror doubleMirror = PrimitiveMirror(TypeKind.\iDOUBLE, "double");

TypeMirror booleanMirror = PrimitiveMirror(TypeKind.\iBOOLEAN, "boolean");

TypeMirror intMirror = PrimitiveMirror(TypeKind.\iINT, "int");

TypeMirror byteMirror = PrimitiveMirror(TypeKind.\iBYTE, "byte");

TypeMirror stringMirror = JavaClassType(javaClass<JString>());

TypeMirror objectMirror = JavaClassType(javaClass<Object>());

class JTypeMirror(Type type) satisfies TypeMirror {
    
    shared actual TypeMirror? componentType => null;
    
    shared actual ClassMirror? declaredClass {
        if (type.classOrInterface) {
            assert(is ClassOrInterface decl = type.declaration);
            
            return JClassMirror(decl);
        }
        
        return null;
    }
    
    shared actual TypeKind kind => TypeKind.\iDECLARED;
    
    shared actual TypeMirror? lowerBound => null;
    
    shared actual Boolean primitive => false;
    
    shared actual String qualifiedName => type.asQualifiedString();
    
    shared actual TypeMirror? qualifyingType => null;
    
    shared actual Boolean raw => type.raw;
    
    shared actual List<TypeMirror> typeArguments {
        value args = ArrayList<TypeMirror>();
        
        for (arg in type.typeArgumentList) {
            args.add(JTypeMirror(arg));
        }
        
        return args;
    }
    
    shared actual TypeParameterMirror? typeParameter => null;
    
    shared actual TypeMirror? upperBound => null;
    
    string => type.asString();
}

class PrimitiveMirror(TypeKind _kind, String name) satisfies TypeMirror {
    shared actual TypeMirror? componentType => null;
    
    shared actual ClassMirror? declaredClass => null;
    
    shared actual TypeKind kind => _kind;
    
    shared actual TypeMirror? lowerBound => null;
    
    shared actual Boolean primitive => true;
    
    shared actual String qualifiedName => name;
    
    shared actual TypeMirror? qualifyingType => null;
    
    shared actual Boolean raw => false;
    
    shared actual List<TypeMirror> typeArguments
            => Collections.emptyList<TypeMirror>();
    
    shared actual TypeParameterMirror? typeParameter => null;
    
    shared actual TypeMirror? upperBound => null;
    
    string => name;
}

class JavaClassType<Type>(Class<Type> type) extends ReflectionType(type)
        given Type satisfies Object {
    string => type.simpleName;
}