/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.loader.impl.reflect.mirror {
    ReflectionType
}
import org.eclipse.ceylon.model.loader.mirror {
    TypeMirror,
    TypeKind
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    ClassOrInterface
}

import java.lang {
    Types {
        classForType
    },
    JString=String
}
import java.util {
    List,
    Collections,
    ArrayList
}

TypeMirror longMirror = PrimitiveMirror(TypeKind.long, "long");

TypeMirror doubleMirror = PrimitiveMirror(TypeKind.double, "double");

TypeMirror booleanMirror = PrimitiveMirror(TypeKind.boolean, "boolean");

TypeMirror intMirror = PrimitiveMirror(TypeKind.int, "int");

TypeMirror byteMirror = PrimitiveMirror(TypeKind.byte, "byte");

TypeMirror stringMirror = JavaClassType<JString>();

TypeMirror objectMirror = JavaClassType<Object>();

class JTypeMirror(Type type) satisfies TypeMirror {
    
    componentType => null;
    
    declaredClass
            => if (is ClassOrInterface decl = type.declaration)
            then JClassMirror(decl)
            else null;
    
    kind => TypeKind.declared;
    
    lowerBound => null;
    
    primitive => false;
    
    qualifiedName => type.asQualifiedString();
    
    qualifyingType => null;
    
    raw => type.raw;
    
    shared actual List<TypeMirror> typeArguments {
        value args = ArrayList<TypeMirror>();
        for (arg in type.typeArgumentList) {
            args.add(JTypeMirror(arg));
        }
        return args;
    }
    
    typeParameter => null;
    
    upperBound => null;
    
    string => type.asString();
}

class PrimitiveMirror(TypeKind _kind, String name)
        satisfies TypeMirror {

    componentType => null;
    
    declaredClass => null;
    
    kind => _kind;
    
    lowerBound => null;
    
    primitive => true;
    
    qualifiedName => name;
    
    qualifyingType => null;
    
    raw => false;
    
    typeArguments => Collections.emptyList<TypeMirror>();
    
    typeParameter => null;
    
    upperBound => null;
    
    string => name;
}

class JavaClassType<Type>()
        extends ReflectionType(classForType<Type>())
        given Type satisfies Object {
    string => super.string.replaceFirst("Reflection", "JavaClass");
}