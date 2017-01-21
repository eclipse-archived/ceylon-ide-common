import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter
}

import java.util {
    Collections,
    Arrays,
    List
}

shared class JTypeParameterMirror(TypeParameter param, {TypeMirror*}(TypeParameter) retrieveBounds) satisfies TypeParameterMirror {
    name = param.nameAsString;
    variable List<TypeMirror>? bounds_ = null;
    bounds => bounds_ else (bounds_ = 
        let(theBounds = retrieveBounds(param))
        if (theBounds.empty) then Collections.emptyList<TypeMirror>()
        else Arrays.asList(*theBounds));
}
