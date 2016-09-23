import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value
}

import java.util {
    Collections
}

shared class JSetterMirror(Value decl)
        extends AbstractMethodMirror(decl) {
    
    constructor => false;
    
    declaredVoid => true;

    final => true;
    
    name => "set" + capitalize(decl.name);
    
    parameters
            => Collections.singletonList<VariableMirror>(JVariableMirror(decl));
    
    returnType => JTypeMirror(decl.type);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    defaultMethod => false;
    
    String capitalize(String str) 
            => (str.first?.uppercased?.string else "") + str.rest;
}