import com.redhat.ceylon.model.loader.model {
    LazyModuleManager
}
import java.util {
    JSet=Set,
    HashSet,
    Collections,
    JList=List
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Modules,
    Package,
    ModuleImport
}
import com.redhat.ceylon.ide.common.util {
    toJavaStringList,
    Path
}
import java.lang {
    JString=String,
    JIterable=Iterable
}
import com.redhat.ceylon.compiler.java.util {
    Util
}
import ceylon.interop.java {
    javaString,
    CeylonIterable
}
import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
shared abstract class BaseIdeModuleManager(BaseCeylonProject? theCeylonProject) 
        extends LazyModuleManager() {

    shared default BaseCeylonProject? ceylonProject = theCeylonProject;

    shared variable default late BaseIdeModuleSourceMapper moduleSourceMapper;

    shared JSet<String> sourceModules;
    shared Boolean loadDependenciesFromModelLoaderFirst;
    
    shared variable late TypeChecker typeChecker;
    
    variable IdeModelLoader? _modelLoader=null;
    
    if (exists theCeylonProject) {
        loadDependenciesFromModelLoaderFirst = theCeylonProject.loadDependenciesFromModelLoaderFirst;
    }
    else {
        loadDependenciesFromModelLoaderFirst = false;
    }
    sourceModules = HashSet<String>();
    if (!loadDependenciesFromModelLoaderFirst) {
        sourceModules.add(Module.\iLANGUAGE_MODULE_NAME);
    }

    shared actual default IdeModelLoader modelLoader {
        if (exists ml = _modelLoader) {
            return ml;
        } else {
            // The JDTModelLoader sets the reference to itself in the ModuleManager 
            // at the beginning of its constructor, so that it's not necessary to assign it here
            // This avoids the weak ref entry of the model loaders static hash map 
            // to be freed just after it's set at the end of the JDTModelLoader constructor."
            return newModelLoader(this, moduleSourceMapper, modules);
        }
    }
    assign modelLoader {
        _modelLoader = modelLoader;
    }
    
    shared formal IdeModelLoader newModelLoader(
        BaseIdeModuleManager self, 
        BaseIdeModuleSourceMapper sourceMapper, 
        Modules modules);

    shared actual void initCoreModules(variable Modules modules) {
        setModules(modules);
        if (!exists m = modules.languageModule) {
            value defaultModuleName = Collections.singletonList(javaString(Module.\iDEFAULT_MODULE_NAME));
            BaseIdeModule defaultModule = createModule(defaultModuleName, "unversioned");
            defaultModule.default = true;
            defaultModule.available = true;
            defaultModule.isProjectModule=true;
            modules.listOfModules.add(defaultModule);
            modules.defaultModule = defaultModule;
            JList<JString> languageName = toJavaStringList {"ceylon", "language"};
            variable Module languageModule = createModule(languageName, TypeChecker.\iLANGUAGE_MODULE_VERSION);
            languageModule.languageModule = languageModule;
            languageModule.available = false;
            modules.languageModule = languageModule;
            modules.listOfModules.add(languageModule);
            defaultModule.addImport(ModuleImport(languageModule, false, false));
            defaultModule.languageModule = languageModule;
            createPackage("", defaultModule);
        }
        super.initCoreModules(modules);
    }
    
    shared actual Package createPackage(variable String pkgName, variable Module \imodule) {
        return modelLoader.findOrCreatePackage(\imodule, pkgName);
    }
    
    shared Boolean isExternalModuleLoadedFromSource(String moduleName) 
            => sourceModules.contains(moduleName);
    
    shared actual Boolean isModuleLoadedFromSource(variable String moduleName) {
        if (isExternalModuleLoadedFromSource(moduleName)) {
            return true;
        }
        if (isModuleLoadedFromCompiledSource(moduleName)) {
            return true;
        }
        return false;
    }
    
    shared Boolean isModuleLoadedFromCompiledSource(String moduleName) {
        if (!ceylonProject exists) {
            return false;
        }
        assert(exists cp=ceylonProject);
        if (moduleFileInProject(moduleName, cp)) {
            return true;
        }
        if (!loadDependenciesFromModelLoaderFirst) {
            for (p in cp.referencedCeylonProjects) {
                if (p.nativeProjectIsAccessible,
                    moduleFileInProject(moduleName, p)) {
                    return true;
                }
            }
        }
        return false;
    }
    
    
    shared actual BaseIdeModule createModule(JList<JString> moduleName, String version) {
        String moduleNameString = Util.getName(moduleName);
        value theModule = newModule(moduleNameString, version);
        theModule.name = moduleName;
        theModule.version = version;
        setupIfJDKModule(theModule);
        return theModule;
    }
    
    shared actual void prepareForTypeChecking() =>
            modelLoader.loadStandardModules();
    
    shared actual JIterable<JString> searchedArtifactExtensions =>
            let(extensions = 
        if (loadDependenciesFromModelLoaderFirst)
    then {"car", "jar", "src"}
    else {"jar", "src", "car"})
    toJavaStringList(extensions);
    
    shared Boolean isLoadDependenciesFromModelLoaderFirst() {
        return loadDependenciesFromModelLoaderFirst;
    }

    shared default BaseIdeModule? getArchiveModuleFromSourcePath(String|Path sourceUnitPath) {
        String sourceUnitPathString = switch(sourceUnitPath)
        case(is String) sourceUnitPath
        case(is Path) sourceUnitPath.platformDependentString;
        
        return CeylonIterable(typeChecker.context.modules.listOfModules)
                .narrow<BaseIdeModule>()
                .find((m) => if (m.isCeylonArchive, 
                                    exists sap=m.sourceArchivePath,
                                    sourceUnitPathString.startsWith("``sap``!"))
                                then true 
                                else false);
    }
    
    shared actual void visitedModule(Module theModule, Boolean forCompiledModule) {
        if (forCompiledModule, 
            AbstractModelLoader.isJDKModule(theModule.nameAsString)) {
            modelLoader.addJDKModuleToClassPath(theModule);
        }
    }
    
    shared formal Boolean moduleFileInProject(String moduleName, BaseCeylonProject? ceylonProject);
    shared formal BaseIdeModule newModule(String moduleName, String version);
}

shared abstract class IdeModuleManager<NativeProject>(
    CeylonProject<NativeProject>? theCeylonProject)
        extends BaseIdeModuleManager(theCeylonProject) {
    shared actual CeylonProject<NativeProject>? ceylonProject {
        assert(is CeylonProject<NativeProject>? cp=super.ceylonProject);
        return cp;
    }

}



