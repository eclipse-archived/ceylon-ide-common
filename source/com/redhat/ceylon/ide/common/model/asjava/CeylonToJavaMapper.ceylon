import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.model.loader.mirror {
    TypeMirror,
    ClassMirror,
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Value,
    Function,
    Type,
    ClassOrInterface
}
import com.redhat.ceylon.model.loader.model {
    LazyClass,
    LazyInterface,
    LazyFunction
}

shared alias JavaMirror => ClassMirror|MethodMirror;

shared object ceylonToJavaMapper {
    
    function mapClassOrInterface(ClassOrInterface decl) {
        return [
            switch(decl)
            case (is LazyClass) decl.classMirror
            case (is LazyInterface) decl.classMirror
            else JClassMirror(decl)
        ];
    }
    
    shared JavaMirror[] mapDeclaration(Declaration decl) {
        return switch (decl)
        case (is ClassOrInterface) mapClassOrInterface(decl)
        case (is Value) mapValue(decl)
        case (is Function) [mapFunction(decl)]
        else empty; 
    }
    
    shared TypeMirror mapType(Type type) {
        if (type.union) {
            value types = CeylonIterable(type.caseTypes);
            value nullType = types.find((t) => t.null);
            
            if (exists nullType, type.caseTypes.size() == 2) {
                // Return the non-null type
                value nonNull = types.find((t) => t != nullType);
                assert(exists nonNull);
                return mapType(nonNull);
            } else {
                return objectMirror;
            }
        }

        if (type.integer) {
            return longMirror;
        } else if (type.float) {
            return doubleMirror;
        } else if (type.boolean) {
            return booleanMirror;
        } else if (type.character) {
            return intMirror;
        } else if (type.byte) {
            return byteMirror;
        } else if (type.isString()) {
            return stringMirror;
        }
        
        return JTypeMirror(type);
    }
    
    JToplevelFunctionMirror|MethodMirror mapFunction(Function func) {
        return if (is LazyFunction func)
        then func.methodMirror
        else if (func.toplevel)
        then JToplevelFunctionMirror(func)
        else JMethodMirror(func);
    }
    
    <JGetterMirror|JSetterMirror|JObjectMirror>[] mapValue(Value decl) {
        value mirrors = Array<JGetterMirror|JSetterMirror|JObjectMirror|Null>.ofSize(2, null);
        
        if (decl.toplevel) {
            mirrors.set(0, JObjectMirror(decl));
        } else if (decl.shared) {
            mirrors.set(0, JGetterMirror(decl));
            
            if (decl.variable) {
                mirrors.set(1, JSetterMirror(decl));
            }
        }
        
        return mirrors.coalesced.sequence();
    }
}