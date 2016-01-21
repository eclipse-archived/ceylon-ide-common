import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Class,
    Value,
    Function,
    Type
}
import com.redhat.ceylon.model.loader.mirror {
    TypeMirror
}

shared alias JavaMirror => JClassMirror|JGetterMirror|JSetterMirror|JMethodMirror;

object ceylonToJavaMapper {
    
    shared JavaMirror[] mapDeclaration(Declaration decl) {
        return switch (decl)
        case (is Class) sequence({JClassMirror(decl)})
        case (is Value) mapValue(decl)
        case (is Function) sequence({JMethodMirror(decl)})
        else empty; 
    }
    
    shared TypeMirror mapType(Type type) {
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
    
    <JGetterMirror|JSetterMirror>[] mapValue(Value decl) {
        value mirrors = Array<JGetterMirror|JSetterMirror|Null>.ofSize(2, null);
        
        if (decl.shared) {
            mirrors.set(0, JGetterMirror(decl));
            
            if (decl.variable) {
                mirrors.set(1, JSetterMirror(decl));
            }
        }
        
        return mirrors.coalesced.sequence();
    }
}