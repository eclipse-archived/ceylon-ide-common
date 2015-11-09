import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit() 
        extends TypecheckerUnit() 
        satisfies IUnit & SourceAware  {
    
    shared actual BaseIdeModule ceylonModule {
        assert(is BaseIdeModule ideModule=\ipackage.\imodule);
        return ideModule;
    }
    
    shared actual Package ceylonPackage {
        return \ipackage;
    }

    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
