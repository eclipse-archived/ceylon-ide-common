import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.common.config {
    CeylonConfig,
    CeylonConfigFinder,
    ConfigWriter
}

import java.io {
    File,
    FileReader,
    IOException
}
import java.lang {
    JBoolean=Boolean
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

    shared File ideConfigFile => File(File(project.rootDirectory, ".ceylon"), "ide-config");

    void initMergedConfig() {
        mergedConfig = CeylonConfig.createFromLocalDir(project.rootDirectory);
    }

    void initIdeConfig() {
        File configFile = ideConfigFile;
        variable CeylonConfig? searchedConfig = null;
        if (configFile.\iexists() && configFile.file) {
            try {
                searchedConfig = CeylonConfigFinder.loadConfigFromFile(configFile);
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

    shared String? systemRepository => ideConfig.get("project.system-repository");
    assign systemRepository {
        this.isSystemRepositoryChanged = true;
        this.transientSystemRepository = systemRepository;
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

        transientCompileToJvm = null;
        transientCompileToJs = null;
        transientSystemRepository = null;
    }

    shared void save() {
        initIdeConfig();

        Boolean someSettingsChanged = isCompileToJvmChanged || isCompileToJsChanged || isSystemRepositoryChanged;

        if (!ideConfigFile.\iexists() || someSettingsChanged) {
            try {
                if (isCompileToJvmChanged) { ideConfig.setBoolOption("project.compile-jvm", transientCompileToJvm else false); }
                if (isCompileToJsChanged) { ideConfig.setBoolOption("project.compile-js", transientCompileToJs else false); }
                if (isCompileToJvmChanged) { ideConfig.setOption("project.system-repository", transientSystemRepository else ""); }

                ConfigWriter.instance().write(ideConfig, ideConfigFile);
                refresh();
                project.refreshConfigFile(projectRelativePath);
            } catch (IOException e) {
                throw Exception("", e);
            }
        }
    }
}
