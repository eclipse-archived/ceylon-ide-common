import com.redhat.ceylon.common.config {
    CeylonConfig,
    Repositories { 
        Repository 
    },
    CeylonConfigFinder,
    DefaultToolOptions,
    ConfigWriter
 }
import java.io {
    File,
    IOException
}

import ceylon.interop.java {
    javaStringArray,
    javaObjectArray,
    toStringArray
}
import java.lang {
    ObjectArray,
    JBoolean = Boolean,
    JString = String
}
import com.redhat.ceylon.common {
    Constants
}

/*
shared class EclipseCeylonProjectConfig(IProject ideArtifact)
    extends CeylonProjectConfig<IProject>(EclipseProject(ideArtifact)) {
    IPath outputRepoPath => ideArtifact.getFullPath().append(outputRepoProjectRelativePath);
}

*/


shared {String*} resourceDirectoriesFromCeylonConfig(CeylonConfig config)
        => getConfigValuesAsList(config, DefaultToolOptions.\iCOMPILER_RESOURCE, Constants.\iDEFAULT_RESOURCE_DIR);

shared {String*} sourceDirectoriesFromCeylonConfig(CeylonConfig config) 
        => getConfigValuesAsList(config, DefaultToolOptions.\iCOMPILER_SOURCE, Constants.\iDEFAULT_SOURCE_DIR);

shared String removeCurrentDirPrefix(String url) 
        => if (url.startsWith("./") || url.startsWith(".\\")) then url.spanFrom(2) else url;

{String*} getConfigValuesAsList(CeylonConfig config, String optionKey, String defaultKey)
        => let (ObjectArray<JString>? values = config.getOptionValues(optionKey))
                if (exists values)
                    then toStringArray(values.array).coalesced
                    else { defaultKey };

void setConfigValuesAsList(CeylonConfig config, String optionKey, {String*} values) 
        => config.setOptionValues(optionKey, javaStringArray(Array<String>(values)));



shared class CeylonProjectConfig<IdeArtifact>(project)
    given IdeArtifact satisfies Object {

    shared CeylonProject<IdeArtifact> project;
    
    late variable CeylonConfig mergedConfig;
    late variable CeylonConfig projectConfig;
    late shared Repositories mergedRepositories;
    late shared Repositories projectRepositories;
    
    variable String? transientOutputRepo = null;
    variable {String*}? transientProjectLocalRepos = null;
    variable {String*}? transientProjectRemoteRepos = null;
    
    variable Boolean isOfflineChanged = false;
    variable Boolean isEncodingChanged = false;
    variable Boolean? transientOffline = null;
    variable String? transientEncoding = null;
    
    variable {String*}? transientSourceDirectories = null;
    variable {String*}? transientResourceDirectories = null;
    
    
    
    File projectConfigFile => File(File(project.rootDirectory, ".ceylon"), "config");
    
    void initMergedConfig() {
        mergedConfig = CeylonConfig.createFromLocalDir(project.rootDirectory);
        mergedRepositories = Repositories.withConfig(mergedConfig);
    }
    
    void initProjectConfig() {
        File configFile = projectConfigFile;
        if (configFile.\iexists() && configFile.file) {
            try {
                projectConfig = CeylonConfigFinder.loadConfigFromFile(configFile);
            } catch (IOException e) {
                throw Exception(null, e);
            }
        } else {
            projectConfig = CeylonConfig();
        }
        projectRepositories = Repositories.withConfig(projectConfig);
    }

    initMergedConfig();
    initProjectConfig();
    
    shared String outputRepo => mergedRepositories.outputRepository.url;
    assign outputRepo {
        transientOutputRepo = outputRepo;
    }
    
    "Project-relative path of the output repository.
       
     Path separator is a '/'"
    shared String outputRepoProjectRelativePath =>
            removeCurrentDirPrefix(outputRepo);
    
    shared {String*} globalLookupRepos => toRepositoriesUrlList(mergedRepositories.globalLookupRepositories);
    
    shared {String*} otherRemoteRepos => toRepositoriesUrlList(mergedRepositories.otherLookupRepositories);
    
    shared {String*} projectLocalRepos=> toRepositoriesUrlList(projectRepositories.getRepositoriesByType(Repositories.\iREPO_TYPE_LOCAL_LOOKUP));
    assign projectLocalRepos {
        transientProjectLocalRepos = projectLocalRepos;
    }
    
    shared {String*} projectRemoteRepos => toRepositoriesUrlList(projectRepositories.getRepositoriesByType(Repositories.\iREPO_TYPE_REMOTE_LOOKUP));
    assign projectRemoteRepos {
        transientProjectRemoteRepos = projectRemoteRepos;
    }
    
    shared String encoding => mergedConfig.getOption(DefaultToolOptions.\iDEFAULTS_ENCODING);
    
    shared String projectEncoding => projectConfig.getOption(DefaultToolOptions.\iDEFAULTS_ENCODING);
    assign projectEncoding {
        isEncodingChanged = true;
        transientEncoding = projectEncoding;
    }
    
    
    shared Boolean offline => mergedConfig.getBoolOption(DefaultToolOptions.\iDEFAULTS_OFFLINE, false);
    
    shared Boolean? projectOffline => let (JBoolean? option = projectConfig.getBoolOption(DefaultToolOptions.\iDEFAULTS_OFFLINE)) option?.booleanValue();
    assign projectOffline {
        this.isOfflineChanged = true;
        this.transientOffline = projectOffline;
    }
    
    shared {String*} sourceDirectories => sourceDirectoriesFromCeylonConfig(mergedConfig);
    
    shared {String*} projectSourceDirectories => sourceDirectoriesFromCeylonConfig(projectConfig);
    assign projectSourceDirectories {
        transientSourceDirectories = projectSourceDirectories;
    }


    shared {String*} resourceDirectories => resourceDirectoriesFromCeylonConfig(mergedConfig);
    
    shared {String*} projectResourceDirectories => resourceDirectoriesFromCeylonConfig(projectConfig);
    assign projectResourceDirectories {
        transientResourceDirectories = projectResourceDirectories;
    }
    
    shared void refresh() {
        
        initMergedConfig();
        initProjectConfig();
        isOfflineChanged = false;
        isEncodingChanged = false;
        transientEncoding = null;
        transientOffline = null;
        transientOutputRepo = null;
        transientProjectLocalRepos = null;
        transientProjectRemoteRepos = null;
        transientSourceDirectories = null;
        transientResourceDirectories = null;
    }
    
    shared void save() {
        initProjectConfig();
        
        String oldOutputRepo = outputRepo;
        {String*} oldProjectLocalRepos = projectLocalRepos;
        {String*} oldProjectRemoteRepos = projectRemoteRepos;
        {String*} oldSourceDirectories = projectSourceDirectories;
        {String*} oldResourceDirectories = projectResourceDirectories;
        
        function changed<T>(T? transientOne, T oldOne)
                given T satisfies Object => if (exists tr=transientOne, tr != oldOne) then transientOne else null;
        
        String? changedOutputRepo = changed(transientOutputRepo, oldOutputRepo);
        {String*}? changedProjectLocalRepos = changed(transientProjectLocalRepos, oldProjectLocalRepos);
        {String*}? changedProjectRemoteRepos = changed(transientProjectRemoteRepos, oldProjectRemoteRepos);
        {String*}? changedSourceDirs = changed(transientSourceDirectories, oldSourceDirectories);
        {String*}? changedResourceDirs = changed(transientResourceDirectories, oldResourceDirectories);
        
        project.fixHiddenOutputFolder(removeCurrentDirPrefix(oldOutputRepo));
        if (exists changedOutputRepo) {
            project.deleteOldOutputFolder(removeCurrentDirPrefix(oldOutputRepo));
            project.createNewOutputFolder(removeCurrentDirPrefix(changedOutputRepo));
        } else if (exists newOutputRepo = transientOutputRepo) {
            // For newly-created projects
            project.createNewOutputFolder(removeCurrentDirPrefix(newOutputRepo));
        }
        
        Boolean someSettingsChanged = changedOutputRepo exists 
                || changedProjectLocalRepos exists 
                || changedProjectRemoteRepos exists 
                || changedSourceDirs exists 
                || changedResourceDirs exists 
                || isOfflineChanged 
                || isEncodingChanged;
        
        if (! project.hasConfigFile || 
            someSettingsChanged) {
            try {
                if (exists changedOutputRepo) {
                    value newOutputRepo = Repositories.SimpleRepository("", transientOutputRepo, null);
                    projectRepositories.setRepositoriesByType(Repositories.\iREPO_TYPE_OUTPUT, javaObjectArray(Array<Repository?> { newOutputRepo }));
                }
                if (exists changedProjectLocalRepos) {
                    value newLocalRepos = toRepositoriesArray(transientProjectLocalRepos);
                    projectRepositories.setRepositoriesByType(Repositories.\iREPO_TYPE_LOCAL_LOOKUP, newLocalRepos);
                }
                if (exists changedProjectRemoteRepos) {
                    value newRemoteRepos = toRepositoriesArray(transientProjectRemoteRepos);
                    projectRepositories.setRepositoriesByType(Repositories.\iREPO_TYPE_REMOTE_LOOKUP, newRemoteRepos);
                }
                if (isOfflineChanged, exists changedOffline = transientOffline) {
                    projectConfig.setBoolOption(DefaultToolOptions.\iDEFAULTS_OFFLINE, changedOffline);
                }
                if (isEncodingChanged, exists changedEncoding = transientEncoding) {
                    projectConfig.setOption(DefaultToolOptions.\iDEFAULTS_ENCODING, changedEncoding);
                }
                if (exists changedSourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_SOURCE, changedSourceDirs);
                }
                if (exists changedResourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_RESOURCE, changedResourceDirs);
                }
                
                ConfigWriter.write(projectConfig, projectConfigFile);
                refresh();
                project.refreshConfigFile();
            } catch (IOException e) {
                throw Exception("", e);
            }
        }
    }
    

    {String*} toRepositoriesUrlList(ObjectArray<Repository>? repositories)
        => if (exists repositories)
                then { for (repository in repositories.iterable.coalesced) repository.url }
                else empty;
    
    ObjectArray<Repository> toRepositoriesArray({String*}? repositoriesUrl) 
        => if (exists repositoriesUrl) 
            then javaObjectArray(Array<Repository?> { 
                for (url in repositoriesUrl) Repositories.SimpleRepository("", url, null) 
            })
            else ObjectArray<Repository>(0);
}
