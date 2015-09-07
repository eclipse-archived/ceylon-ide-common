import com.redhat.ceylon.common.config {
    CeylonConfig,
    Repositories,
    CeylonConfigFinder,
    ConfigWriter
}
import java.io {
    File,
    IOException
}
import java.lang {
    JBoolean=Boolean
}

shared interface JavaToCeylonConverterConfig {
    shared formal Boolean transformGetters;
    shared formal Boolean useVariableInParameters;
    shared formal Boolean useVariableInLocals;
    shared formal Boolean useValues;
}

shared class CeylonIdeConfig<IdeArtifact>(shared CeylonProject<IdeArtifact> project) {
    late variable CeylonConfig mergedConfig;
    late variable CeylonConfig ideConfig;
    late variable Repositories mergedRepositories;
    late variable Repositories projectRepositories;
    
    variable Boolean? transientCompileToJvm = null;
    variable Boolean? transientCompileToJs = null;
    variable String? transientSystemRepository = null;
    
    variable Boolean isCompileToJvmChanged = false;
    variable Boolean isCompileToJsChanged = false;
    variable Boolean isSystemRepositoryChanged = false;
    
    File ideConfigFile => File(File(project.rootDirectory, ".ceylon"), "ide-config");
    
    void initMergedConfig() {
        mergedConfig = CeylonConfig.createFromLocalDir(project.rootDirectory);
        mergedRepositories = Repositories.withConfig(mergedConfig);
    }
    
    void initIdeConfig() {
        File configFile = ideConfigFile;
        if (configFile.\iexists() && configFile.file) {
            try {
                ideConfig = CeylonConfigFinder.loadConfigFromFile(configFile);
            } catch (IOException e) {
                throw Exception(null, e);
            }
        } else {
            ideConfig = CeylonConfig();
        }
        projectRepositories = Repositories.withConfig(ideConfig);
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
        shared actual Boolean transformGetters => ideConfig.getBoolOption("converter.transform-getters", false);
        shared actual Boolean useValues => ideConfig.getBoolOption("converter.use-values", false);
        shared actual Boolean useVariableInLocals => ideConfig.getBoolOption("converter.use-variable-in-locals", true);
        shared actual Boolean useVariableInParameters => ideConfig.getBoolOption("converter.use-variable-in-parameters", true);
    };
    
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
        
        Boolean someSettingsChanged = isCompileToJsChanged || isCompileToJsChanged || isSystemRepositoryChanged;
        
        if (!ideConfigFile.\iexists() || someSettingsChanged) {
            try {
                ideConfig.setBoolOption("project.compile-jvm", transientCompileToJvm else false);
                ideConfig.setBoolOption("project.compile-js", transientCompileToJs else false);
                ideConfig.setOption("project.system-repository", transientSystemRepository else "");
                
                ConfigWriter.write(ideConfig, ideConfigFile);
                refresh();
            } catch (IOException e) {
                throw Exception("", e);
            }
        }
    }
}
