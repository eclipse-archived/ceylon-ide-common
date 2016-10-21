import com.redhat.ceylon.common {
    Constants
}
import com.redhat.ceylon.common.config {
    CeylonConfig,
    ConfigWriter,
    ConfigFinder
}

import java.io {
    File,
    FileReader,
    IOException
}
import java.lang {
    System {
        systemProperty=getProperty
    }
}
import java.util {
    Properties
}
import java.util.regex {
    Pattern
}

shared interface JavaToCeylonConverterConfig {
    shared formal Boolean transformGetters;
    shared formal Boolean useValues;
}

shared class CeylonIdeConfig(shared BaseCeylonProject project) {
    late variable CeylonConfig mergedConfig;
    late variable CeylonConfig ideConfig;

    variable Boolean? transientCompileToJvm = null;
    variable Boolean? transientCompileToJs = null;
    variable String? transientSystemRepository = null;

    variable Boolean isCompileToJvmChanged = false;
    variable Boolean isCompileToJsChanged = false;
    variable Boolean isSystemRepositoryChanged = false;

    shared String projectRelativePath = ".ceylon/ide-config";

    ConfigFinder configFinder = ConfigFinder("ide-config", "ceylon.ide-config");
    
    shared File ideConfigFile => File(File(project.rootDirectory, ".ceylon"), "ide-config");

    void initMergedConfig() {
        mergedConfig = configFinder.loadDefaultConfig(project.rootDirectory);
    }

    void initIdeConfig() {
        File configFile = ideConfigFile;
        if (configFile.\iexists() && configFile.file) {
            try {
                ideConfig = configFinder.loadConfigFromFile(configFile);
            } catch (IOException e) {
                throw Exception(null, e);
            }
        }
        else {
            ideConfig = CeylonConfig();
        }
    }

    initMergedConfig();
    initIdeConfig();

    Boolean isExe(String p) =>
            let(f = File(p))
            f.\iexists() && f.canExecute();

    value windowsPaths = { 
        "C:\\Program Files\\nodejs\\",
        "C:\\Program Files (x86)\\nodejs\\"
    };
    
    value windowsExtensions = { 
        ".exe",
        ".cmd"
    };
    
    value windowsPathsAndExtensions = windowsPaths.product(windowsExtensions);

    value unixLikePaths = let(home = process.propertyValue("user.home")) {
        if (exists home) "`` home ``/bin" }.chain {
        "/usr/local/bin/",
        "/usr/bin/",
        "/bin/",
        "/opt/bin/"
    };
            
    value unixLikePathsAndExtensions = unixLikePaths.map((p) => [p, ""]);

    value possiblePathsAndExtensions = concatenate(
        unixLikePathsAndExtensions,
        windowsPathsAndExtensions);

    String? searchForNodeOrNpmPath(String* commandsWithoutExtension) => {
        for (cmdName in commandsWithoutExtension)
        for ([path, extension] in possiblePathsAndExtensions)
        path + cmdName + extension
    }.find(isExe);
    
    shared Boolean? compileToJvm =>
            ideConfig.getBoolOption("project.compile-jvm")?.booleanValue();
    assign compileToJvm {
        this.isCompileToJvmChanged = true;
        this.transientCompileToJvm = compileToJvm;
    }

    shared Boolean? compileToJs =>
            ideConfig.getBoolOption("project.compile-js")?.booleanValue();
    assign compileToJs {
        this.isCompileToJsChanged = true;
        this.transientCompileToJs = compileToJs;
    }

    shared String? systemRepository => CeylonConfig.get("project.system-repository");
    assign systemRepository {
        this.isSystemRepositoryChanged = true;
        this.transientSystemRepository = systemRepository;
    }

    shared String? nodePath => 
            if (exists fromConfig = ideConfig.getOption("js.node-path"))
            then fromConfig
            else if (exists fromSystem = systemProperty(Constants.propCeylonExtcmdNode))
            then fromSystem
            else searchForNodeOrNpmPath("node", "nodejs");

    shared String? npmPath => 
            if (exists fromConfig = ideConfig.getOption("js.npm-path"))
            then fromConfig
            else if (exists fromSystem = systemProperty(Constants.propCeylonExtcmdNpm))
            then fromSystem
            else searchForNodeOrNpmPath("npm");
    
    shared JavaToCeylonConverterConfig converterConfig
            => object satisfies JavaToCeylonConverterConfig {
                transformGetters => ideConfig.getBoolOption("converter.transform-getters", true);
                useValues => ideConfig.getBoolOption("converter.use-values", false);
            };

    shared String? getSourceAttachment(String moduleName, String moduleVersion) {
        value propertiesFile = File(
            project.rootDirectory,
            ideConfig.getOption(
                "source.attachments",
                ".ceylon/attachments.properties"));

        value optionPattern = "^(``Pattern.quote(moduleName)``|\\*)/(``Pattern.quote(moduleVersion)``|\\*)/path";

        if (propertiesFile.\iexists()) {
            value properties = Properties();
            properties.load(FileReader(propertiesFile));
            value propName =
                    { for (name in properties.stringPropertyNames())
                      if (name.matches(optionPattern)) name.string };
            return if (exists srcPath
                    = propName.max(byDecreasing((String x) => x.count('*'.equals))))
                then properties.getProperty(srcPath)
                else null;
        }

        return null;
    }

    shared void refresh() {
        initMergedConfig();
        initIdeConfig();

        isCompileToJvmChanged = false;
        isCompileToJsChanged = false;
        isSystemRepositoryChanged = false;

        transientCompileToJvm = null;
        transientCompileToJs = null;
        transientSystemRepository = null;
    }

    shared void save() {
        initIdeConfig();

        Boolean someSettingsChanged = 
                isCompileToJvmChanged || 
                isCompileToJsChanged || 
                isSystemRepositoryChanged;

        if (!ideConfigFile.\iexists() || someSettingsChanged) {
            try {
                if (isCompileToJvmChanged) {
                    ideConfig.setBoolOption("project.compile-jvm", transientCompileToJvm else false);
                }
                if (isCompileToJsChanged) {
                    ideConfig.setBoolOption("project.compile-js", transientCompileToJs else false);
                }
                if (isCompileToJvmChanged) {
                    ideConfig.setOption("project.system-repository", transientSystemRepository else "");
                }

                ConfigWriter.instance().write(ideConfig, ideConfigFile);
                refresh();
                project.refreshConfigFile(projectRelativePath);
            } catch (IOException e) {
                throw Exception("", e);
            }
        }
    }
}
