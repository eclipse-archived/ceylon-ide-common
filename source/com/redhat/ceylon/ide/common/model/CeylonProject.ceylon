import java.io {
    File,
    IOException
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits
}
import com.redhat.ceylon.tools.bootstrap {
    CeylonBootstrapTool,
    CeylonBootstrapMessages
}
import com.redhat.ceylon.common {
    Constants,
    FileUtil,
    Versions
}
import com.redhat.ceylon.launcher {
    Bootstrap
}

shared abstract class CeylonProject<IdeArtifact>()
        given IdeArtifact satisfies Object {

    variable CeylonProjectConfig<IdeArtifact>? ceylonConfig = null;
    variable CeylonIdeConfig<IdeArtifact>? ideConfig = null;
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";

    shared formal IdeArtifact ideArtifact;
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

    shared CeylonProjectConfig<IdeArtifact> configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig<IdeArtifact>(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }
    
    shared CeylonIdeConfig<IdeArtifact> ideConfiguration {
        if (exists config = ideConfig) {
            return config;
        } else {
            value newConfig = CeylonIdeConfig<IdeArtifact>(this);
            ideConfig = newConfig;
            return newConfig;
        }
    }

    "Returns:
     - [[true]] if no error occured while creating the ceylon bootstrap files,
     - [[false]] if the boostrap files already exist and [[force]] is [[false]],
     - An error message if an [[IOException]] occured during creation of the bootstrap files."
    shared Boolean|String createBootstrapFiles(File embeddedDistributionFolder, Boolean force=false) {
        value bootstrapGrandParent = File(File(File(embeddedDistributionFolder, "repo"), "ceylon"), "bootstrap");
        value versionDir = bootstrapGrandParent.listFiles().array[0];
        if(! exists versionDir) {
            return "The embedded repository is not accessible";
        }
        value bootstrapJar = File(versionDir, "ceylon.bootstrap-``versionDir.name``.jar");
        if(! bootstrapJar.\iexists()) {
            return "The 'ceylon.bootstrap' archive is not accessible in the embedded repository";
        }

        value binDirectory = File(embeddedDistributionFolder, "bin");
        if(! bootstrapJar.\iexists()) {
            return "The 'bin' folder is not accessible in the embedded repository";
        }

        if (!force) {
            value scriptFile = FileUtil.applyCwd(rootDirectory, File("ceylonb"));
            value batFile = FileUtil.applyCwd(rootDirectory, File("ceylonb.bat"));
            value bootstrapDir = File(FileUtil.applyCwd(rootDirectory, File(Constants.\iCEYLON_CONFIG_DIR)), "bootstrap");
            value propsFile = File(bootstrapDir, Bootstrap.\iFILE_BOOTSTRAP_PROPERTIES);
            value jarFile = File(bootstrapDir, Bootstrap.\iFILE_BOOTSTRAP_JAR);
            if (scriptFile.\iexists() || batFile.\iexists() || propsFile.\iexists() || jarFile.\iexists()) {
                return false;
            }
        }
        try {
            CeylonBootstrapTool.setupBootstrap(rootDirectory, bootstrapJar, binDirectory, null, null, null);
        } catch(IOException ioe) {
            return ioe.message;
        }
        return true;
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

    suppressWarnings("expressionTypeNothing")
    shared object modules satisfies Iterable<IdeModule> {
        shared IdeModule default
                => if (is IdeModule m=phasedUnits.moduleManager.modules.defaultModule) then m else nothing;
        shared IdeModule language
                => if (is IdeModule m=phasedUnits.moduleManager.modules.languageModule) then m else nothing;
        iterator()
                => object satisfies Iterator<IdeModule> {
            value it = phasedUnits.moduleManager.modules.listOfModules.iterator();
            next() => let(m=it.next()) if (is IdeModule m) then m else nothing;
        };

        shared {IdeModule*} fromProject
                => filter((m) => m.projectModule);

        shared {IdeModule*} external
                => filter((m) => ! m.projectModule);

        shared IdeModuleManager manager => if (is IdeModuleManager mm=phasedUnits.moduleManager) then mm else nothing;
        shared IdeModuleSourceMapper sourceMapper => if (is IdeModuleSourceMapper msm=phasedUnits.moduleSourceMapper) then msm else nothing;
    }

    shared {String*} ceylonRepositories
        => let (c = configuration) c.projectLocalRepos
            .chain(c.globalLookupRepos)
            .chain(c.projectRemoteRepos)
            .chain(c.otherRemoteRepos);
}

