import com.redhat.ceylon.model.typechecker.model {
    Type
}
shared interface ExtractTypedRefactoring satisfies AbstractRefactoring {
    shared formal Type? type;
}

shared interface ExtractInferrableTypedRefactoring satisfies ExtractTypedRefactoring {
    shared formal variable Boolean explicitType;
    shared formal Boolean canBeInferred;
}