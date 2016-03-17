import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit 
        extends TypecheckerUnitWithConstructor 
        satisfies IUnit & SourceAware  {
    shared new(BaseIdeModuleSourceMapper moduleSourceMapper) 
            extends TypecheckerUnitWithConstructor(moduleSourceMapper) {}

    shared new init(String theFilename, String theRelativePath, String theFullPath, Package thePackage) 
            extends TypecheckerUnitWithConstructor(theFilename, theRelativePath, theFullPath, thePackage) {}
    
    shared actual BaseIdeModule ceylonModule =>
            unsafeCast<BaseIdeModule>(\ipackage.\imodule);
    
    shared actual Package ceylonPackage =>
            \ipackage;

    shared actual Package? javaLangPackage => 
            ceylonModule.ceylonProject?.modules?.javaLangPackage 
                else super.javaLangPackage;
    
    shared actual default BaseIdeModuleSourceMapper? moduleSourceMapper =>
            unsafeCast<BaseIdeModuleSourceMapper?>(super.moduleSourceMapper);
    
    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
