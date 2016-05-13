import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit 
        extends TypecheckerUnit
        satisfies IUnit & SourceAware  {
    shared new(BaseIdeModuleSourceMapper? moduleSourceMapper) 
            extends TypecheckerUnit(moduleSourceMapper) {}

    shared new init(String theFilename, String theRelativePath, String theFullPath, Package thePackage) 
            extends TypecheckerUnit(theFilename, theRelativePath, theFullPath, thePackage) {}
    
    shared actual BaseIdeModule ceylonModule =>
            unsafeCast<BaseIdeModule>(\ipackage.\imodule);
    
    shared actual Package ceylonPackage =>
            \ipackage;

    shared actual Package? javaLangPackage => 
            ceylonModule.ceylonProject?.modules?.javaLangPackage 
                else super.javaLangPackage;
    
    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
