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
    toStringArray,
    javaClass,
    CeylonIterable
}
import java.lang {
    ObjectArray,
    JBoolean = Boolean,
    JString = String,
    IllegalArgumentException
}
import com.redhat.ceylon.common {
    Constants
}
import java.util {
    EnumSet
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    Warning
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

{String*}|Default getConfigValuesAsList<Default=Nothing>(CeylonConfig config, String optionKey, String|Default defaultKey)
        given Default satisfies Null
        => let (ObjectArray<JString>? values = config.getOptionValues(optionKey))
                if (exists values)
                    then toStringArray(values.array).coalesced
                    else if (is Default defaultKey) then defaultKey else { defaultKey };

void setConfigValuesAsList(CeylonConfig config, String optionKey, {String*}? values) {
        if (exists values) {
            config.setOptionValues(optionKey, javaStringArray(Array<String>(values)));
        } else {
            config.removeOption(optionKey);
        }
}


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
    variable Boolean isOverridesChanged = false;
    variable Boolean? transientOffline = null;
    variable String? transientEncoding = null;
    variable String? transientOverrides = null;

    variable {String*}? transientSourceDirectories = null;
    variable {String*}? transientResourceDirectories = null;

    variable {String*}? transientSuppressWarnings = null;
    variable Boolean isSuppressWarningsChanged = false;


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

    shared String? overrides => DefaultToolOptions.getDefaultOverrides(mergedConfig);

    shared String? projectOverrides => DefaultToolOptions.getDefaultOverrides(projectConfig);
    assign projectOverrides {
        this.isOverridesChanged = true;
        this.transientOverrides = projectOverrides;
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

    shared EnumSet<Warning> suppressWarningsEnum
        => let (suppressWarnings = getConfigValuesAsList(mergedConfig, DefaultToolOptions.\iCOMPILER_SUPPRESSWARNING, null))
                buildSuppressWarningsEnum(suppressWarnings);

    shared {String*}? projectSuppressWarnings
        => getConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_SUPPRESSWARNING, null);

     assign projectSuppressWarnings {
        transientSuppressWarnings = projectSuppressWarnings;
        isSuppressWarningsChanged = true;
    }

    shared EnumSet<Warning> projectSuppressWarningsEnum
        => buildSuppressWarningsEnum(projectSuppressWarnings);

    "CAUTION : When assigned from Java code, take care of not passing a null value"
    assign projectSuppressWarningsEnum {
        {String*}? ws;
        if (projectSuppressWarningsEnum.empty) {
            ws = null;
        } else if (projectSuppressWarningsEnum.containsAll(EnumSet<Warning>.allOf(javaClass<Warning>()))) {
            ws = {};
        } else {
            ws = { for (w in CeylonIterable(projectSuppressWarningsEnum)) w.name() };
        }
        transientSuppressWarnings = ws;
        isSuppressWarningsChanged = true;
    }


    EnumSet<Warning> buildSuppressWarningsEnum({String*}? suppressWarnings) {
        if (! exists suppressWarnings) {
            return EnumSet<Warning>.noneOf(javaClass<Warning>());
        }
        else if (suppressWarnings.empty) {
            return EnumSet<Warning>.allOf(javaClass<Warning>());
        }
        else if ([*suppressWarnings] == [""]) {
            //special case because all warnings is encoded as the empty string
            return EnumSet<Warning>.allOf(javaClass<Warning>());
        }
        else {
            EnumSet<Warning> suppressedWarnings = EnumSet<Warning>.noneOf(javaClass<Warning>());
            for (name in suppressWarnings) {
                try {
                    suppressedWarnings.add(Warning.valueOf(name.trimmed));
                }
                catch (IllegalArgumentException iae) {}
            }
            return suppressedWarnings;
        }
    }





    shared void refresh() {

        initMergedConfig();
        initProjectConfig();
        isOfflineChanged = false;
        isEncodingChanged = false;
        isOverridesChanged = false;
        isSuppressWarningsChanged = false;
        transientEncoding = null;
        transientOffline = null;
        transientOverrides = null;
        transientOutputRepo = null;
        transientProjectLocalRepos = null;
        transientProjectRemoteRepos = null;
        transientSourceDirectories = null;
        transientResourceDirectories = null;
        transientSuppressWarnings = null;
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
                || isEncodingChanged
                || isOverridesChanged
                || isSuppressWarningsChanged;

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
                if (isOverridesChanged) {
                    projectConfig.setOption(DefaultToolOptions.\iDEFAULTS_OFFLINE, transientOverrides);
                }
                if (isEncodingChanged) {
                    projectConfig.setOption(DefaultToolOptions.\iDEFAULTS_ENCODING, transientEncoding);
                }
                if (exists changedSourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_SOURCE, changedSourceDirs);
                }
                if (exists changedResourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_RESOURCE, changedResourceDirs);
                }
                if (isSuppressWarningsChanged) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.\iCOMPILER_SUPPRESSWARNING, transientSuppressWarnings);
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
