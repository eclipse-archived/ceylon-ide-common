import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    ClassMirror,
    VariableMirror,
    TypeMirror,
    AnnotationMirror
}
import java.util {
    List,
    Collections,
    ArrayList
}
import com.redhat.ceylon.model.typechecker.model {
    Class,
    ParameterList
}

class JConstructorMirror(Class cls, ParameterList pl) satisfies MethodMirror {
    
    abstract => false;
    
    constructor => true;
    
    declaredVoid => false;
    
    default => false;
    
    defaultAccess => !cls.shared;
    
    defaultMethod => false;
    
    shared actual ClassMirror? enclosingClass => null;
    
    final => false;
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    name => cls.name;
    
    shared actual List<VariableMirror> parameters {
        value vars = ArrayList<VariableMirror>();
        
        for (p in pl.parameters) {
            vars.add(JVariableMirror(p));
        }
        
        return vars;
    }
    
    protected => false;
    
    public => cls.shared;
    
    shared actual TypeMirror? returnType => null; // TODO I think
    
    static => false;
    
    staticInit => false;
    
    typeParameters => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
}