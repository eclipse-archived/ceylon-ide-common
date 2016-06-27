import com.redhat.ceylon.model.loader.mirror {
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue
}

shared abstract class AbstractMethodMirror(shared FunctionOrValue decl)
        satisfies MethodMirror {
    
    abstract => decl.abstraction;
    
    default => decl.default;
    
    defaultAccess => !decl.shared;
    
    enclosingClass => null;
    
    getAnnotation(String? string) => null;
    
    protected => false;
    
    public => decl.shared;
    
    shared actual default Boolean static => false;
    
    staticInit => false;
}