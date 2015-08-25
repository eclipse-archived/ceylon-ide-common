import com.redhat.ceylon.model.typechecker.model {
    Type
}
shared interface ExtractTypedRefactoring<RefactoringData> satisfies AbstractRefactoring<RefactoringData> {
    shared formal Type? type;
}

shared interface ExtractInferrableTypedRefactoring<RefactoringData> satisfies ExtractTypedRefactoring<RefactoringData> {
    shared formal variable Boolean explicitType;
    shared formal Boolean canBeInferred;
}