import org.eclipse.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    Value
}

import java.util {
    Collections
}

shared class JGetterMirror(Value decl)
        extends AbstractMethodMirror(decl) {
    
    constructor => false;
    
    declaredVoid => false;
    
    final => true;
    
    name => "get" + capitalize(decl.name);
    
    parameters
            => Collections.emptyList<VariableMirror>();
    
    returnType => ceylonToJavaMapper.mapType(decl.type);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    String capitalize(String str) {
        return (str.first?.uppercased?.string else "") + str.rest;
    }
    
    defaultMethod => false;
    
}
