import org.eclipse.ceylon.model.loader.mirror {
    MethodMirror
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    Function
}

import java.util {
    List,
    Collections
}

shared class JToplevelFunctionMirror(Function decl)
        extends AbstractClassMirror(decl) {

    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => true;
    
    ceylonToplevelObject => false;
    
    satisfiedTypes => Collections.emptyList<Type>();
    
    supertype => null;
    
    name => super.name + "_";
    
    scanExtraMembers(List<MethodMirror> methods)
            => methods.add(JMethodMirror(decl, true));
}
