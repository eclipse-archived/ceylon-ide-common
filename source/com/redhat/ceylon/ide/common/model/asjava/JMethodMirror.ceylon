import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

import java.util {
    List,
    Collections,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}

shared class JMethodMirror(Function decl, Boolean forceStatic = false)
        extends AbstractMethodMirror(decl) {
    
    shared actual Boolean constructor => false;
    
    shared actual Boolean declaredVoid => decl.declaredVoid;
    
    shared actual Boolean final => true;
    
    shared actual String name => decl.name;
    
    shared actual List<VariableMirror> parameters {
        List<VariableMirror> vars = ArrayList<VariableMirror>();
        
        CeylonIterable(decl.firstParameterList.parameters)
            .each((p) => vars.add(JVariableMirror(p)));
        
        return vars;
    }
    
    shared actual TypeMirror returnType => ceylonToJavaMapper.mapType(decl.type);
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    shared actual Boolean variadic => decl.variable;
    
    shared actual Boolean defaultMethod => false;
    
    static => forceStatic then true else super.static;
}