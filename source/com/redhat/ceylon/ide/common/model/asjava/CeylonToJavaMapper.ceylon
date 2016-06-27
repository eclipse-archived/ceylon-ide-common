import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.model.loader.mirror {
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Value,
    Function,
    Type,
    ClassOrInterface
}

shared alias JavaMirror => JClassMirror|JObjectMirror|JGetterMirror|JSetterMirror|JMethodMirror|JToplevelFunctionMirror;

shared object ceylonToJavaMapper {
    
    shared JavaMirror[] mapDeclaration(Declaration decl) {
        return switch (decl)
        case (is ClassOrInterface) sequence({JClassMirror(decl)})
        case (is Value) mapValue(decl)
        case (is Function) sequence({mapFunction(decl)})
        else empty; 
    }
    
    shared TypeMirror mapType(Type type) {
        Type simplifiedType;
        
        if (type.union) {
            value types = CeylonIterable(type.caseTypes);
            value nullType = types.find((t) => t.null);
            
            if (exists nullType, type.caseTypes.size() == 2) {
                // Return the non-null type
                value nonNull = types.find((t) => t != nullType);
                assert(exists nonNull);
                simplifiedType = nonNull;
            } else {
                return objectMirror;
            }
        } else {
            simplifiedType = type;
        }

        if (simplifiedType.integer) {
            return longMirror;
        } else if (simplifiedType.float) {
            return doubleMirror;
        } else if (simplifiedType.boolean) {
            return booleanMirror;
        } else if (simplifiedType.character) {
            return intMirror;
        } else if (simplifiedType.byte) {
            return byteMirror;
        } else if (simplifiedType.isString()) {
            return stringMirror;
        }
        
        return JTypeMirror(simplifiedType);
    }
    
    JToplevelFunctionMirror|JMethodMirror mapFunction(Function func) {
        return func.toplevel
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