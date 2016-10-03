import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

import java.util {
    List,
    Collections,
    ArrayList
}

shared class JMethodMirror(Function decl, Boolean forceStatic = false)
        extends AbstractMethodMirror(decl) {
    
    constructor => false;
    
    declaredVoid => decl.declaredVoid;
    
    final => true;
    
    name => decl.name;
    
    shared actual List<VariableMirror> parameters {
        value vars = ArrayList<VariableMirror>();
        for (p in decl.firstParameterList.parameters) {
            vars.add(JVariableMirror(p));
        }
        return vars;
    }
    
    returnType => ceylonToJavaMapper.mapType(decl.type);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => decl.variable;
    
    defaultMethod => false;
    
    static => forceStatic then true else super.static;
}
