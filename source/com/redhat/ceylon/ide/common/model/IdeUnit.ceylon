import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit() 
        extends TypecheckerUnit() 
        satisfies IUnit {
    
    shared actual BaseIdeModule ceylonModule {
        assert(is BaseIdeModule ideModule=\ipackage.\imodule);
        return ideModule;
    }
    
    shared actual Package ceylonPackage {
        return \ipackage;
    }

    shared formal String? sourceFileName;
    shared formal String? sourceRelativePath;
    shared formal String? sourceFullPath;
}
