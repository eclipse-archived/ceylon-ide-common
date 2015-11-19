import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}

shared abstract class IdeUnit() 
        extends TypecheckerUnit() 
        satisfies IUnit & SourceAware  {
    
    shared actual BaseIdeModule ceylonModule =>
            unsafeCast<BaseIdeModule>(\ipackage.\imodule);
    
    shared actual Package ceylonPackage =>
            \ipackage;

    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
