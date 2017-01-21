import com.redhat.ceylon.compiler.java.codegen {
    Strategy
}
import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Generic,
    Declaration,
    TypeParameter,
    TypeDeclaration
}

import java.util {
    List,
    Collections,
    Arrays
}

shared interface GenericMirror<GenericType>
        satisfies DeclarationBasedMirror<GenericType>
        given GenericType satisfies Generic & Declaration {
    shared formal TypeParameterMirror toTypeParamterMirror(TypeParameter tp);
    
    """
       Logic extracted from `ClassTransformer.transformTypeParameters()` 
       """
    shared default List<TypeParameterMirror> buildTypeParameters() =>
        if (exists typeParameters = Strategy.getEffectiveTypeParameters(declaration))
        then Arrays.asList(
            for (param in declaration.typeParameters) 
                if (is TypeDeclaration container =  param.container)
                    toTypeParamterMirror(param)
        )
        else Collections.emptyList<TypeParameterMirror>();
    
}
