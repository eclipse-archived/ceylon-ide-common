import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter
}

import java.util {
    Collections
}

shared class JTypeParameterMirror(TypeParameter param) satisfies TypeParameterMirror {
    
    bounds => Collections.emptyList<TypeMirror>();
    
    name => param.nameAsString;
    
}
