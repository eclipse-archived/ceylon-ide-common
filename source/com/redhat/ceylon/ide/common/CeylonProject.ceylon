import java.io {
    File
}

shared abstract class CeylonProject<IdeArtifact>()
        given IdeArtifact satisfies Object {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    shared formal IdeArtifact ideArtifact;
    shared formal File rootDirectory;
    shared formal Boolean hasConfigFile;

    "Un-hide a previously hidden output folder in old Eclipse projects
     For other IDEs, do nothing"
    shared default void fixHiddenOutputFolder(String folderProjectRelativePath) => noop();
    shared formal void deleteOldOutputFolder(String folderProjectRelativePath);
    shared formal void createNewOutputFolder(String folderProjectRelativePath);
    shared formal void refreshConfigFile();

    variable CeylonProjectConfig<IdeArtifact>? ceylonConfig = null;
    shared CeylonProjectConfig<IdeArtifact> configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig<IdeArtifact>(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }

    shared String defaultCharset
        => configuration.encoding;
}

