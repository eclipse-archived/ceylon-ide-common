/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.loader.mirror {
    TypeMirror,
    ClassMirror,
    MethodMirror
}
import org.eclipse.ceylon.model.loader.model {
    LazyClass,
    LazyInterface,
    LazyFunction
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Value,
    Function,
    Type,
    ClassOrInterface
}

shared object ceylonToJavaMapper {

    function mapFunction(Function func) {
        if (is LazyFunction func) {
            return [func.methodMirror];
        }
        else {
            return func.toplevel
                then [JToplevelFunctionMirror(func)]
                else [JMethodMirror(func)];
        }
    }

    function mapValue(Value decl) {
        if (decl.toplevel) { //TODO: can this possibly be correct??! decl.anonymous, no?
            return [JObjectMirror(decl)];
        }
        else if (decl.shared) {
            return decl.variable
                then [JGetterMirror(decl), JSetterMirror(decl)]
                else [JGetterMirror(decl)];
        }
        else {
            return [];
        }
    }
    function mapClassOrInterface(ClassOrInterface decl)
            => switch (decl)
            case (is LazyClass) [decl.classMirror]
            case (is LazyInterface) [decl.classMirror]
            else [JClassMirror(decl)];

    shared <ClassMirror|MethodMirror>[] mapDeclaration(Declaration decl)
            => switch (decl)
            case (is ClassOrInterface) mapClassOrInterface(decl)
            case (is Value) mapValue(decl)
            case (is Function) mapFunction(decl)
            else [];
    
    shared TypeMirror mapType(Type type) {
        if (type.union) {
            value unit = type.declaration.unit;
            if (unit.isOptionalType(type)) {
                // Return the non-null type
                return mapType(unit.getDefiniteType(type));
            }
        }
        else {
            return objectMirror;
        }

        return if (type.integer) then longMirror
          else if (type.float) then doubleMirror
          else if (type.boolean) then booleanMirror
          else if (type.character) then intMirror
          else if (type.byte) then byteMirror
          else if (type.isString()) then stringMirror
          else JTypeMirror(type);

    }

}