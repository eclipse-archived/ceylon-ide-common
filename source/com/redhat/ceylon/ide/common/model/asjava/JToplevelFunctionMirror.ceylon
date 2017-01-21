import com.redhat.ceylon.model.loader.mirror {
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Function
}

import java.util {
    List,
    Collections
}

shared class JToplevelFunctionMirror(Function decl, mapper)
        extends AbstractClassMirror<Function>(decl, null) {
    shared actual CeylonToJavaMapper mapper;

    abstract => false;
    ceylonToplevelAttribute => false;
    ceylonToplevelMethod => true;
    ceylonToplevelObject => false;
    satisfiedTypes => Collections.emptyList<Type>();
    name => super.name + "_";
    supertype => null;
    
    ceylonAnnotations => super.ceylonAnnotations.chain {
        CeylonAnnotations.method.entry
    };
    
    declarationForName => declaration;
    
    scanExtraMembers(List<MethodMirror> methods)
            => methods.add(object extends JMethodMirror(decl, outer, outer.mapper) {
            ceylonAnnotations => [];
    });
    
    extraInterfaces => [];
}
