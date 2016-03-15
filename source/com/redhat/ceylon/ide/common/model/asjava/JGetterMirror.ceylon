import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value
}

import java.util {
    List,
    Collections
}

shared class JGetterMirror(Value decl) extends AbstractMethodMirror(decl) {
    
    shared actual Boolean constructor => false;
    
    shared actual Boolean declaredVoid => false;
    
    shared actual Boolean final => true;
    
    shared actual String name => "get" + capitalize(decl.name);
    
    shared actual List<VariableMirror> parameters
            => Collections.emptyList<VariableMirror>();
    
    shared actual TypeMirror returnType => ceylonToJavaMapper.mapType(decl.type);
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    shared actual Boolean variadic => false;
    
    String capitalize(String str) {
        return (str.first?.uppercased?.string else "") + str.rest;
    }
    
    shared actual Boolean defaultMethod => false;
    
}