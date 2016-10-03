import com.redhat.ceylon.model.loader.mirror {
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue
}
import java.util {
    Collections
}
import java.lang {
    JString=String
}

shared abstract class AbstractMethodMirror(shared FunctionOrValue decl)
        satisfies MethodMirror & DeclarationMirror {
    
    declaration => decl;
    
    abstract => decl.abstraction;
    
    default => decl.default;
    
    defaultAccess => !decl.shared;
    
    enclosingClass => null;
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    protected => false;
    
    public => decl.shared;
    
    shared actual default Boolean static => decl.staticallyImportable;
    
    staticInit => false;
}