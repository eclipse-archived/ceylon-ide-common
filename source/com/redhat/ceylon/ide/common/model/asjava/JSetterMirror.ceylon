import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror,
    ClassMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value
}

import java.util {
    Collections
}

shared class JSetterMirror(Value decl, ClassMirror? enclosingClass, mapper)
        extends AbstractMethodMirror<Value>(decl, enclosingClass) {
    
    shared actual CeylonToJavaMapper mapper;
    variable Integer? flags_ = null;
    
    flags => flags_ else 
    (flags_ = mapper.transformer.modifierTransformation().getterSetter(decl, false));
    
    constructor => false;
    
    declaredVoid => true;

    name => "set" + capitalize(decl.name);
    
    parameters
            => Collections.singletonList<VariableMirror>(JSetterParameterMirror(decl, mapper));
    
    returnType => PrimitiveMirror.\ivoid;
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    defaultMethod => false;
    
    String capitalize(String str) 
            => (str.first?.uppercased?.string else "") + str.rest;
}