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

shared class JSetterMirror(Value decl) extends AbstractMethodMirror(decl) {
    
    shared actual Boolean constructor => false;
    
    shared actual Boolean declaredVoid => true;

    shared actual Boolean final => true;
    
    shared actual String name => "set" + capitalize(decl.name);
    
    shared actual List<VariableMirror> parameters
            => Collections.singletonList<VariableMirror>(JVariableMirror(decl));
    
    shared actual TypeMirror returnType => nothing;
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    shared actual Boolean variadic => false;
    
    shared actual Boolean defaultMethod => false;
    
    String capitalize(String str) 
            => (str.first?.uppercased?.string else "") + str.rest;
}