import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.common.config {
    CeylonConfig,
    CeylonConfigFinder,
    ConfigWriter,
    ConfigFinder
}

import java.io {
    File,
    FileReader,
    IOException
}
import java.lang {
    JBoolean=Boolean,
    System {
        systemProperty = getProperty
    }
}
import java.util {
    Properties
}
import java.util.regex {
    Pattern
}
import com.redhat.ceylon.common {
    Constants
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
    variable {String*}? transientJavacOptions = null;

    variable Boolean isCompileToJvmChanged = false;
    variable Boolean isCompileToJsChanged = false;
    variable Boolean isSystemRepositoryChanged = false;
    variable Boolean isJavacOptionsChanged = false;

    shared String projectRelativePath = ".ceylon/ide-config";

    ConfigFinder configFinder = ConfigFinder("ide-config", "ceylon.ide-config");
    
    shared File ideConfigFile => File(File(project.rootDirectory, ".ceylon"), "ide-config");

    void initMergedConfig() {
        mergedConfig = configFinder.loadDefaultConfig(project.rootDirectory);
    }

    void initIdeConfig() {
        File configFile = ideConfigFile;
        variable CeylonConfig? searchedConfig = null;
        if (configFile.\iexists() && configFile.file) {
            try {
                searchedConfig = configFinder.loadConfigFromFile(configFile);
            } catch (IOException e) {
                throw Exception(null, e);
            }
        }
        if (exists existingConfig=searchedConfig) {
            ideConfig = existingConfig;
        } else {
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

    value unixLikePaths = {
        "/usr/bin/",
        "/usr/local/",
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
    
    shared Boolean? compileToJvm => let (JBoolean? option = ideConfig.getBoolOption("project.compile-jvm")) option?.booleanValue();
    assign compileToJvm {
        this.isCompileToJvmChanged = true;
        this.transientCompileToJvm = compileToJvm;
    }

    shared Boolean? compileToJs => let (JBoolean? option = ideConfig.getBoolOption("project.compile-js")) option?.booleanValue();
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
    
    deprecated("Use [[CeylonProjectConfig.javacOptions]] instead.")
    shared {String*}? javacOptions => getConfigValuesAsList(ideConfig, "project.javac", null);
    assign javacOptions {
        this.isJavacOptionsChanged = true;
        this.transientJavacOptions = javacOptions;
    }
    
    shared JavaToCeylonConverterConfig converterConfig => object satisfies JavaToCeylonConverterConfig {
        shared actual Boolean transformGetters => ideConfig.getBoolOption("converter.transform-getters", true);
        shared actual Boolean useValues => ideConfig.getBoolOption("converter.use-values", false);
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
            value srcPaths =
                    CeylonIterable(properties.stringPropertyNames())
                    .filter((name)=> name.matches(optionPattern))
                    .map((s)=>s.string)
                    .sort((x, y) => x.count('*'.equals) <=> y.count('*'.equals))
                    .map((name) => properties.getProperty(name.string));
            return srcPaths.first;
        }

        return null;
    }

    shared void refresh() {
        initMergedConfig();
        initIdeConfig();

        isCompileToJvmChanged = false;
        isCompileToJsChanged = false;
        isSystemRepositoryChanged = false;
        isJavacOptionsChanged = false;

        transientCompileToJvm = null;
        transientCompileToJs = null;
        transientSystemRepository = null;
        transientJavacOptions = null;
    }

    shared void save() {
        initIdeConfig();

        Boolean someSettingsChanged = 
                isCompileToJvmChanged || 
                isCompileToJsChanged || 
                isSystemRepositoryChanged ||
                isJavacOptionsChanged;

        if (!ideConfigFile.\iexists() || someSettingsChanged) {
            try {
                if (isCompileToJvmChanged) { ideConfig.setBoolOption("project.compile-jvm", transientCompileToJvm else false); }
                if (isCompileToJsChanged) { ideConfig.setBoolOption("project.compile-js", transientCompileToJs else false); }
                if (isCompileToJvmChanged) { ideConfig.setOption("project.system-repository", transientSystemRepository else ""); }
                if (isJavacOptionsChanged) { 
                    setConfigValuesAsList(ideConfig, "project.javac", transientJavacOptions);
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
