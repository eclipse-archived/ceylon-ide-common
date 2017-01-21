import com.redhat.ceylon.langtools.tools.javac.code {
    Flags
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    ClassMirror
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue
}

shared abstract class AbstractMethodMirror<DeclarationType>(DeclarationType decl, enclosingClass = null)
        extends DeclarationMirror<DeclarationType>(decl)
        satisfies MethodMirror
        given DeclarationType satisfies FunctionOrValue {
    
    shared formal Integer flags;
    
    shared actual default Boolean abstract => flags.and(Flags.abstract) > 0;
    shared actual default Boolean default => flags.and(Flags.default) > 0;
    shared actual default Boolean defaultAccess => flags.and(Flags.accessFlags) == 0;
    shared actual ClassMirror? enclosingClass;
    shared actual default Boolean protected => flags.and(Flags.protected) > 0;
    shared actual default Boolean public => flags.and(Flags.public) > 0;
    shared actual default Boolean static => declaration.static;
    shared actual default Boolean staticInit => false;
    shared actual default Boolean final => flags.and(Flags.final) > 0;
}