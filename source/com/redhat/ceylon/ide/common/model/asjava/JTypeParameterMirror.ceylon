import com.redhat.ceylon.model.typechecker.model {
    TypeParameter
}
import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    TypeMirror
}
import java.util {
    List,
    Collections
}

shared class JTypeParameterMirror(TypeParameter param) satisfies TypeParameterMirror {
    
    shared actual List<TypeMirror> bounds => Collections.emptyList<TypeMirror>();
    
    shared actual String name => param.nameAsString;
    
    
}