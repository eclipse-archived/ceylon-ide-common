import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class IdeUnit 
        extends TypecheckerUnit
        satisfies IUnit & SourceAware  {
    
    shared new(BaseIdeModuleSourceMapper? moduleSourceMapper) 
            extends TypecheckerUnit(moduleSourceMapper) {}

    shared new init(String theFilename, 
                    String theRelativePath, 
                    String theFullPath, 
                    Package thePackage) 
            extends TypecheckerUnit(theFilename, 
                                    theRelativePath, 
                                    theFullPath, 
                                    thePackage) {}
    
    shared actual BaseIdeModule ceylonModule {
        assert (is BaseIdeModule ideModule = \ipackage.\imodule);
        return ideModule;
    }
    
    shared actual Package ceylonPackage 
            => \ipackage;

    shared actual Package? javaLangPackage 
            => ceylonModule.ceylonProject
                ?.modules?.javaLangPackage 
                else super.javaLangPackage;
    assign javaLangPackage
            => super.javaLangPackage = javaLangPackage;
    
    shared actual formal String? sourceFileName;
    shared actual formal String? sourceRelativePath;
    shared actual formal String? sourceFullPath;
}
