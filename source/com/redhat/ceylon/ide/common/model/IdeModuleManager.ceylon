import ceylon.collection {
    HashSet,
    MutableSet
}
import ceylon.interop.java {
    JavaIterable
}

import com.redhat.ceylon.common {
    Backend,
    Backends
}
import com.redhat.ceylon.compiler.java.util {
    Util
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}
import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.loader.model {
    LazyModuleManager
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Modules,
    Package,
    ModuleImport
}

import java.io {
    JFile=File
}
import java.lang {
    Types {
        nativeString
    },
    JString=String,
    JIterable=Iterable
}
import java.util {
    Collections,
    JList=List,
    Arrays
}

shared abstract class BaseIdeModuleManager(shared default BaseCeylonProjects model, BaseCeylonProject? theCeylonProject) 
        extends LazyModuleManager() 
        satisfies LazyModuleManagerEx {

    value languageModuleName = Arrays.asList(*Module.languageModuleName.split('.'.equals).map(nativeString));
    value defaultModuleName = Collections.singletonList(nativeString(Module.defaultModuleName));

    shared default BaseCeylonProject? ceylonProject = theCeylonProject;

    shared variable default late BaseIdeModuleSourceMapper moduleSourceMapper;

    shared MutableSet<String> sourceModules;
    shared Boolean loadDependenciesFromModelLoaderFirst;
    
    shared variable late TypeChecker typeChecker;
    
    variable BaseIdeModelLoader? _modelLoader=null;
    
    if (exists theCeylonProject) {
        loadDependenciesFromModelLoaderFirst = theCeylonProject.loadDependenciesFromModelLoaderFirst;
    }
    else {
        loadDependenciesFromModelLoaderFirst = false;
    }
    sourceModules = HashSet<String>();
    if (!loadDependenciesFromModelLoaderFirst) {
        sourceModules.add(Module.languageModuleName);
    }

    shared actual default BaseIdeModelLoader modelLoader {
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
    
    shared actual void initModelLoader(AbstractModelLoader modelLoader) {
        assert(is BaseIdeModelLoader modelLoader);
        _modelLoader = modelLoader;
    }
    
    shared formal BaseIdeModelLoader newModelLoader(
        BaseIdeModuleManager self, 
        BaseIdeModuleSourceMapper sourceMapper, 
        Modules modules);

    shared actual void initCoreModules(variable Modules modules) {
        setModules(modules);
        if (!exists m = modules.languageModule) {
            BaseIdeModule defaultModule = createModule(defaultModuleName, "unversioned");
            //defaultModule.default = true;
            defaultModule.available = true;
            defaultModule.isProjectModule=true;
            modules.listOfModules.add(defaultModule);
            modules.defaultModule = defaultModule;
            variable Module languageModule = createModule(languageModuleName, TypeChecker.languageModuleVersion);
            languageModule.languageModule = languageModule;
            languageModule.available = false;
            modules.languageModule = languageModule;
            modules.listOfModules.add(languageModule);
            defaultModule.addImport(ModuleImport(null, languageModule, false, false));
            defaultModule.languageModule = languageModule;
            createPackage("", defaultModule);
        }
        super.initCoreModules(modules);
    }
    
    shared actual Package createPackage(variable String pkgName, variable Module \imodule) 
            => modelLoader.findOrCreatePackage(\imodule, pkgName);
    
    shared Boolean isExternalModuleLoadedFromSource(String moduleName) 
            => moduleName in sourceModules;
    
    shared actual Boolean isModuleLoadedFromSource(variable String moduleName) 
            => if (isExternalModuleLoadedFromSource(moduleName))
                then true
            else if (isModuleLoadedFromCompiledSource(moduleName))
                then true
            else false;
    
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
    
    shared BaseCeylonProject? searchForOriginalProject(JFile moduleArtifact) =>
            let (existingArtifactAbsolutePath = moduleArtifact.absolutePath)
            ceylonProject?.referencedCeylonProjects
            ?.filter(BaseCeylonProject.nativeProjectIsAccessible)
            ?.find((refProject) 
                => refProject.ceylonModulesOutputDirectory.absolutePath in existingArtifactAbsolutePath);

    shared BaseIdeModule? searchForOriginalModule(String moduleName, JFile moduleArtifact) =>
            searchForOriginalProject(moduleArtifact)?.modules
            ?.find((m) => m.nameAsString == moduleName && m.isProjectModule);
            
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
            let (extensions = loadDependenciesFromModelLoaderFirst
                    then {"car", "jar", "src", "js"}
                    else {"jar", "src", "car", "js"})
            JavaIterable(extensions.map(nativeString));
    
    shared Boolean isLoadDependenciesFromModelLoaderFirst() =>
            loadDependenciesFromModelLoaderFirst;

    shared default BaseIdeModule? getArchiveModuleFromSourcePath(String|Path sourceUnitPath) {
        String sourceUnitPathString = switch(sourceUnitPath)
        case(is String) sourceUnitPath
        case(is Path) sourceUnitPath.platformDependentString;

        for (m in typeChecker.context.modules.listOfModules) {
            if (is BaseIdeModule m,
                m.isCeylonArchive,
                exists sap = m.sourceArchivePath,
                sourceUnitPathString.startsWith("``sap``!")) {
                return m;
            }
        }
        else {
            return null;
        }

    }
    
    shared actual void visitedModule(Module theModule, Boolean forCompiledModule) {
        if (forCompiledModule, 
            modelLoader.jdkProvider.isJDKModule(theModule.nameAsString)) {
            modelLoader.addJDKModuleToClassPath(theModule);
        }
    }

    "Checks if the [[ceylonProject]] knows how to find the sources for the
     module [[moduleName]]."
    shared formal Boolean moduleFileInProject(String moduleName, BaseCeylonProject? ceylonProject);
    
    shared formal BaseIdeModule newModule(String moduleName, String version);

    
    shared actual Backends supportedBackends {
        // We detect which backends are enabled in the project settings and
        // we return those instead of relying on our super class which will
        // only (and correctly!) return "JVM".
        // This is just a hack of course because we're using this JVM module
        // manager even for the JS backend.
        // TODO At some point we'll need an actual module manager for the
        // JS backend and an IDE that can somehow merge the two when needed
        variable value backends = Backends.any;
        if (exists theProject = ceylonProject) {
            if (theProject.compileToJava) {
                backends = backends.merged(Backend.java);
            }
            if (theProject.compileToJs) {
                backends = backends.merged(Backend.javaScript);
            }
        }
        return backends;
    }
}

shared abstract class IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile>(
    shared actual CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile> model,
    CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>? theCeylonProject)
        extends BaseIdeModuleManager(model, theCeylonProject)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>? ceylonProject =>
            unsafeCast<CeylonProjectAlias?>(super.ceylonProject);

}



