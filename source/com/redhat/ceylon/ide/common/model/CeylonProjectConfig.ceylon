import ceylon.interop.java {
    toStringArray,
    javaClass,
    createJavaObjectArray,
    createJavaStringArray
}

import com.redhat.ceylon.common {
    Constants
}
import com.redhat.ceylon.common.config {
    CeylonConfig,
    Repositories {
        Repository
    },
    CeylonConfigFinder,
    DefaultToolOptions,
    ConfigWriter
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    Warning
}

import java.io {
    File,
    IOException
}
import java.lang {
    ObjectArray,
    IllegalArgumentException
}
import java.util {
    EnumSet
}

/*
shared class EclipseCeylonProjectConfig(IProject ideArtifact)
    extends CeylonProjectConfig<IProject>(EclipseProject(ideArtifact)) {
    IPath outputRepoPath => ideArtifact.getFullPath().append(outputRepoProjectRelativePath);
}

*/

shared {String*} resourceDirectoriesFromCeylonConfig(CeylonConfig config)
        => getConfigValuesAsList(config, DefaultToolOptions.compilerResource, Constants.defaultResourceDir);

shared {String*} sourceDirectoriesFromCeylonConfig(CeylonConfig config)
        => getConfigValuesAsList(config, DefaultToolOptions.compilerSource, Constants.defaultSourceDir);

shared String removeCurrentDirPrefix(String url)
        => if (url.startsWith("./") || url.startsWith(".\\")) then url[2...] else url;

{String*}|Default getConfigValuesAsList<Default=Nothing>(CeylonConfig config, String optionKey, String|Default defaultKey)
        given Default satisfies Null
        => if (exists values = config.getOptionValues(optionKey))
        then toStringArray(values.array).coalesced
        else if (is Default defaultKey) then defaultKey else { defaultKey };

void setConfigValuesAsList(CeylonConfig config, String optionKey, {String*}? values) {
    if (exists values) {
        config.setOptionValues(optionKey, createJavaStringArray(values));
    } else {
        config.removeOption(optionKey);
    }
}

shared class CeylonProjectConfig(project) {

    value warningClass = javaClass<Warning>();

    shared BaseCeylonProject project;

    late variable CeylonConfig mergedConfig;
    late variable CeylonConfig projectConfig;
    late variable Repositories mergedRepositories;
    late variable Repositories projectRepositories;

    variable String? transientOutputRepo = null;
    variable {String*}? transientProjectLocalRepos = null;
    variable {String*}? transientProjectRemoteRepos = null;

    variable Boolean isOfflineChanged = false;
    variable Boolean isEncodingChanged = false;
    variable Boolean isOverridesChanged = false;
    variable Boolean isJdkProviderChanged = false;
    variable Boolean isFlatClasspathChanged = false;
    variable Boolean isAutoExportMavenDependenciesChanged = false;
    variable Boolean? transientOffline = null;
    variable String? transientEncoding = null;
    variable String? transientOverrides = null;
    variable String? transientJdkProvider = null;
    variable Boolean? transientFlatClasspath = null;
    variable Boolean? transientAutoExportMavenDependencies = null;

    variable {String*}? transientSourceDirectories = null;
    variable {String*}? transientResourceDirectories = null;

    variable {String*}? transientSuppressWarnings = null;
    variable Boolean isSuppressWarningsChanged = false;
    
    shared String projectRelativePath = ".ceylon/config";
    
    shared File projectConfigFile => File(File(project.rootDirectory, ".ceylon"), "config");

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

    "The underlying [[CeylonConfig]] object. WARNING: changes made to this object
     will be lost when [[save]] or [[refresh]] are called."
    shared CeylonConfig ceylonConfig => mergedConfig;

    shared Repositories repositories => mergedRepositories;

    shared String outputRepo => mergedRepositories.outputRepository.url;
    assign outputRepo {
        transientOutputRepo = outputRepo;
    }

    "Project-relative path of the output repository.

     Path separator is a '/'"
    shared String outputRepoProjectRelativePath =>
            removeCurrentDirPrefix(outputRepo);

    shared {String*} globalLookupRepos =>
            toRepositoriesUrlList(mergedRepositories.globalLookupRepositories);

    shared {String*} otherRemoteRepos =>
            toRepositoriesUrlList(mergedRepositories.otherLookupRepositories);

    shared {String*} projectLocalRepos=>
            toRepositoriesUrlList(projectRepositories.getRepositoriesByType(Repositories.repoTypeLocalLookup));
    assign projectLocalRepos =>
            transientProjectLocalRepos = projectLocalRepos;

    shared {String*} projectRemoteRepos =>
            toRepositoriesUrlList(projectRepositories.getRepositoriesByType(Repositories.repoTypeRemoteLookup));
    assign projectRemoteRepos =>
            transientProjectRemoteRepos = projectRemoteRepos;

    shared String? encoding =>
            mergedConfig.getOption(DefaultToolOptions.defaultsEncoding);

    shared String? projectEncoding =>
            projectConfig.getOption(DefaultToolOptions.defaultsEncoding);
    assign projectEncoding {
        isEncodingChanged = true;
        transientEncoding = projectEncoding;
    }

    shared Boolean offline =>
            mergedConfig.getBoolOption(DefaultToolOptions.defaultsOffline, false);

    shared Boolean? projectOffline =>
            projectConfig.getBoolOption(DefaultToolOptions.defaultsOffline)?.booleanValue();
    assign projectOffline {
        this.isOfflineChanged = true;
        this.transientOffline = projectOffline;
    }

    shared String? overrides =>
            DefaultToolOptions.getDefaultOverrides(mergedConfig);

    shared String? projectOverrides =>
            DefaultToolOptions.getDefaultOverrides(projectConfig);
    assign projectOverrides {
        this.isOverridesChanged = true;
        this.transientOverrides = projectOverrides;
    }

    shared String? jdkProvider =>
            DefaultToolOptions.getCompilerJdkProvider(mergedConfig);
    shared String? projectJdkProvider =>
            DefaultToolOptions.getCompilerJdkProvider(projectConfig);
    assign projectJdkProvider {
        this.isJdkProviderChanged = true;
        this.transientJdkProvider = projectJdkProvider;
    }

    shared Boolean flatClasspath =>
            DefaultToolOptions.getDefaultFlatClasspath(mergedConfig);

    shared Boolean? projectFlatClasspath =>
            projectConfig.getBoolOption(DefaultToolOptions.defaultsFlatClasspath)?.booleanValue();
    assign projectFlatClasspath {
        this.isFlatClasspathChanged = true;
        this.transientFlatClasspath = projectFlatClasspath;
    }

    shared Boolean autoExportMavenDependencies =>
            DefaultToolOptions.getDefaultAutoExportMavenDependencies(mergedConfig);

    shared Boolean? projectAutoExportMavenDependencies =>
            projectConfig.getBoolOption(DefaultToolOptions.defaultsAutoEportMavenDependencies)?.booleanValue();
    assign projectAutoExportMavenDependencies {
        this.isAutoExportMavenDependenciesChanged = true;
        this.transientAutoExportMavenDependencies = projectAutoExportMavenDependencies;
    }

    shared {String*} sourceDirectories =>
            sourceDirectoriesFromCeylonConfig(mergedConfig);

    shared {String*} projectSourceDirectories =>
            sourceDirectoriesFromCeylonConfig(projectConfig);
    assign projectSourceDirectories =>
            transientSourceDirectories = projectSourceDirectories;


    shared {String*} resourceDirectories =>
            resourceDirectoriesFromCeylonConfig(mergedConfig);

    shared {String*} projectResourceDirectories =>
            resourceDirectoriesFromCeylonConfig(projectConfig);
    assign projectResourceDirectories =>
            transientResourceDirectories = projectResourceDirectories;

    shared EnumSet<Warning> suppressWarningsEnum =>
            let (suppressWarnings = getConfigValuesAsList(mergedConfig, DefaultToolOptions.compilerSuppresswarning, null))
                buildSuppressWarningsEnum(suppressWarnings);

    shared {String*}? projectSuppressWarnings =>
            getConfigValuesAsList(projectConfig, DefaultToolOptions.compilerSuppresswarning, null);

     assign projectSuppressWarnings {
        transientSuppressWarnings = projectSuppressWarnings;
        isSuppressWarningsChanged = true;
    }

    shared EnumSet<Warning> projectSuppressWarningsEnum =>
            buildSuppressWarningsEnum(projectSuppressWarnings);

    "CAUTION : When assigned from Java code, take care of not passing a null value"
    assign projectSuppressWarningsEnum {
        value ws =
            if (projectSuppressWarningsEnum.empty) then null
            else if (projectSuppressWarningsEnum.containsAll(EnumSet<Warning>.allOf(warningClass))) then { "" }
            else { for (w in projectSuppressWarningsEnum) w.name() };
        transientSuppressWarnings = ws;
        isSuppressWarningsChanged = true;
    }

    EnumSet<Warning> buildSuppressWarningsEnum({String*}? suppressWarnings) {
        if (!exists suppressWarnings) {
            return EnumSet<Warning>.noneOf(warningClass);
        }
        else if (suppressWarnings.empty) {
            return EnumSet<Warning>.allOf(warningClass);
        }
        else if (suppressWarnings.sequence() == [""]) {
            //special case because all warnings is encoded as the empty string
            return EnumSet<Warning>.allOf(warningClass);
        }
        else {
            value suppressedWarnings = EnumSet<Warning>.noneOf(warningClass);
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
        isJdkProviderChanged = false;
        isFlatClasspathChanged = false;
        isAutoExportMavenDependenciesChanged = false;
        isSuppressWarningsChanged = false;
        transientEncoding = null;
        transientOffline = null;
        transientOverrides = null;
        transientJdkProvider = null;
        transientFlatClasspath = null;
        transientAutoExportMavenDependencies = null;
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
                given T satisfies Object
                => if (exists transientOne, transientOne!=oldOne)
                then transientOne
                else null;

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

        Boolean someSettingsChanged
                =  changedOutputRepo exists
                || changedProjectLocalRepos exists
                || changedProjectRemoteRepos exists
                || changedSourceDirs exists
                || changedResourceDirs exists
                || isOfflineChanged
                || isEncodingChanged
                || isOverridesChanged
                || isJdkProviderChanged
                || isFlatClasspathChanged
                || isAutoExportMavenDependenciesChanged
                || isSuppressWarningsChanged;

        if (!project.hasConfigFile ||
            someSettingsChanged) {
            try {
                if (exists changedOutputRepo) {
                    value newOutputRepo = Repositories.SimpleRepository("", transientOutputRepo, null);
                    projectRepositories.setRepositoriesByType(Repositories.repoTypeOutput, ObjectArray(1, newOutputRepo));
                }
                if (exists changedProjectLocalRepos) {
                    value newLocalRepos = toRepositoriesArray(transientProjectLocalRepos);
                    projectRepositories.setRepositoriesByType(Repositories.repoTypeLocalLookup, newLocalRepos);
                }
                if (exists changedProjectRemoteRepos) {
                    value newRemoteRepos = toRepositoriesArray(transientProjectRemoteRepos);
                    projectRepositories.setRepositoriesByType(Repositories.repoTypeRemoteLookup, newRemoteRepos);
                }
                if (isOfflineChanged) {
                    if (exists nonNullOffline = transientOffline) {
                        projectConfig.setBoolOption(DefaultToolOptions.defaultsOffline, nonNullOffline);
                    } else {
                        projectConfig.setOption(DefaultToolOptions.defaultsOffline, null);
                    }

                }
                if (isOverridesChanged) {
                    projectConfig.setOption(DefaultToolOptions.defaultsOverrides, transientOverrides);
                }
                if (isJdkProviderChanged) {
                    projectConfig.setOption(DefaultToolOptions.compilerJdkprovider, transientJdkProvider);
                }
                if (isFlatClasspathChanged) {
                    if (exists nonNullFlatClasspath = transientFlatClasspath) {
                        projectConfig.setBoolOption(DefaultToolOptions.defaultsFlatClasspath, nonNullFlatClasspath);
                    } else {
                        projectConfig.setOption(DefaultToolOptions.defaultsFlatClasspath, null);
                    }
                }
                if (isAutoExportMavenDependenciesChanged) {
                    if (exists nonNullAutoExportMavenDependencies = transientAutoExportMavenDependencies) {
                        projectConfig.setBoolOption(DefaultToolOptions.defaultsAutoEportMavenDependencies, nonNullAutoExportMavenDependencies);
                    } else {
                        projectConfig.setOption(DefaultToolOptions.defaultsAutoEportMavenDependencies, null);
                    }
                }
                if (isEncodingChanged) {
                    projectConfig.setOption(DefaultToolOptions.defaultsEncoding, transientEncoding);
                }
                if (exists changedSourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.compilerSource, changedSourceDirs);
                }
                if (exists changedResourceDirs) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.compilerResource, changedResourceDirs);
                }
                if (isSuppressWarningsChanged) {
                    setConfigValuesAsList(projectConfig, DefaultToolOptions.compilerSuppresswarning, transientSuppressWarnings);
                }

                ConfigWriter.instance().write(projectConfig, projectConfigFile);
                refresh();
                project.refreshConfigFile(projectRelativePath);
            } catch (IOException e) {
                throw Exception("", e);
            }
        }
    }


    {String*} toRepositoriesUrlList(ObjectArray<Repository>? repositories)
            => if (exists repositories)
            then { for (repository in repositories.iterable.coalesced) repository.url }
            else {};

    ObjectArray<Repository> toRepositoriesArray({String*}? repositoriesUrl)
            => if (exists repositoriesUrl)
            then createJavaObjectArray {
                for (url in repositoriesUrl)
                Repositories.SimpleRepository("", url, null)
            }
            else ObjectArray<Repository>(0);
}
