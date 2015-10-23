import java.io {
    File
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits
}
import com.redhat.ceylon.ide.common.util {
    Path
}

shared interface Modules satisfies {BaseIdeModule*} {
    shared formal BaseIdeModule default;
    shared formal BaseIdeModule language;
    shared formal {BaseIdeModule*} fromProject;
    shared formal {BaseIdeModule*} external;
    
    shared formal BaseIdeModuleManager manager;
    shared formal BaseIdeModuleSourceMapper sourceMapper;
}


shared abstract class BaseCeylonProject() {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    variable CeylonProjectConfig? ceylonConfig = null;
    variable CeylonIdeConfig? ideConfig = null;
    
    shared formal BaseCeylonProjects model;

    shared formal File rootDirectory;
    shared formal Boolean hasConfigFile;

    "Only here for compatibility with legacy code
     This should be removed, since the real entry point is the [[PhasedUnits]] object
     
     The only interesting data contained in the [[TypeChecker]] is the
     [[phasedUnitsOfDependencies|TypeChecker.phasedUnitsOfDependencies]]. But new they
     should be managed in a modular way in each [[IdeModule]] object accessible from the
     [[PhasedUnits]]"
    shared TypeChecker typechecker=>nothing;
    
    "Should be hidden in the future, when implemented directy here in Ceylon"
    shared PhasedUnits phasedUnits=>nothing;
    
    shared CeylonProjectConfig configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }

    shared CeylonIdeConfig ideConfiguration {
        if (exists config = ideConfig) {
            return config;
        } else {
            value newConfig = CeylonIdeConfig(this);
            ideConfig = newConfig;
            return newConfig;
        }
    }
    
    
    shared String defaultCharset
            => configuration.encoding else defaultDefaultCharset;
    
    shared default String defaultDefaultCharset
            => "utf8";
    
    "Un-hide a previously hidden output folder in old Eclipse projects
     For other IDEs, do nothing"
    shared default void fixHiddenOutputFolder(String folderProjectRelativePath) => noop();
    shared formal void deleteOldOutputFolder(String folderProjectRelativePath);
    shared formal void createNewOutputFolder(String folderProjectRelativePath);
    shared formal void refreshConfigFile();
    
    shared formal Boolean synchronizedWithConfiguration;
    shared formal Boolean nativeProjectIsAccessible;
    shared formal Boolean compileToJs;
    shared formal Boolean compileToJava;

    value loadBinariesFirst => 
            "true".equals(process.propertyValue("ceylon.loadBinariesFirst") else "true");
    
    shared Boolean loadDependenciesFromModelLoaderFirst =>
            compileToJava && loadBinariesFirst;
    
    shared {String*} ceylonRepositories
            => let (c = configuration) c.projectLocalRepos
            .chain(c.globalLookupRepos)
            .chain(c.projectRemoteRepos)
            .chain(c.otherRemoteRepos);

    shared default Boolean isJavaLikeFileName(String fileName) =>
            fileName.endsWith(".java");
    
    shared formal {BaseCeylonProject*} referencedCeylonProjects;
    shared formal {BaseCeylonProject*} referencingCeylonProjects;

    shared File ceylonModulesOutputDirectory =>
            File(
        Path(rootDirectory.absolutePath)
                .append(configuration.outputRepoProjectRelativePath)
                .platformDependentString);
    
    shared formal ModuleDependencies moduleDependencies;

    shared formal Modules modules; 
}

shared abstract class CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProject()
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual formal CeylonProjectsAlias model;
    shared formal NativeProject ideArtifact;
    
    shared actual Modules modules => object satisfies Modules {
        iterator() => object satisfies Iterator<BaseIdeModule> {
            value it = phasedUnits.moduleManager.modules.listOfModules.iterator();
            shared actual BaseIdeModule next() { 
                assert(is BaseIdeModule m=it.next());
                return m;
            }
        };
        
        shared actual BaseIdeModule default {
            assert(is BaseIdeModule m=phasedUnits.moduleManager.modules.defaultModule);
            return m;
        }
        
        shared actual BaseIdeModule language {
            assert(is BaseIdeModule m=phasedUnits.moduleManager.modules.languageModule);
            return m; 
        }
        
        shared actual {BaseIdeModule*} fromProject
                => filter((m) => m.isProjectModule);
        
        shared actual {BaseIdeModule*} external
                => filter((m) => ! m.isProjectModule);
        
        shared actual BaseIdeModuleManager manager {
            assert(is BaseIdeModuleManager mm=phasedUnits.moduleManager);
            return mm; 
        }
        
        shared actual BaseIdeModuleSourceMapper sourceMapper {
            assert(is BaseIdeModuleSourceMapper msm=phasedUnits.moduleSourceMapper);
            return msm;
        }
    };
    
    shared formal {NativeProject*} referencedNativeProjects(NativeProject nativeProject);
    shared formal {NativeProject*} referencingNativeProjects(NativeProject nativeProject);
    
    shared actual {CeylonProjectAlias*} referencedCeylonProjects =>
            referencedNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;

    shared actual {CeylonProjectAlias*} referencingCeylonProjects =>
            referencingNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;
}

