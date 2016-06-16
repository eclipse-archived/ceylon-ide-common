import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    ClassMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue
}

shared abstract class AbstractMethodMirror(shared FunctionOrValue decl)
        satisfies MethodMirror {
    
    shared actual Boolean abstract => decl.abstraction;
    
    shared actual Boolean default => decl.default;
    
    shared actual Boolean defaultAccess => !decl.shared;
    
    shared actual ClassMirror? enclosingClass => null;
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    shared actual Boolean protected => false;
    
    shared actual Boolean public => decl.shared;
    
    shared actual default Boolean static => false;
    
    shared actual Boolean staticInit => false;
}