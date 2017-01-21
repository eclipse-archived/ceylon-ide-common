import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

shared interface DeclarationBasedMirror<DeclarationType>
        satisfies ModelBasedMirror
        given DeclarationType satisfies Declaration {
    
    shared formal DeclarationType declaration;
}
