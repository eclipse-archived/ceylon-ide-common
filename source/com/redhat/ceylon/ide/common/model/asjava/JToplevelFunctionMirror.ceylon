import com.redhat.ceylon.model.loader.mirror {
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Function
}

import java.util {
    ArrayList,
    Collections
}

shared class JToplevelFunctionMirror(shared actual Function decl) extends AbstractClassMirror(decl) {
    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => true;
    
    ceylonToplevelObject => false;
    
    satisfiedTypes => Collections.emptyList<Type>();
    
    supertype => null;
    
    name => super.name + "_";
    
    shared actual void scanExtraMembers(ArrayList<MethodMirror> methods) { 
        methods.add(JMethodMirror(decl, true));
    }
}
