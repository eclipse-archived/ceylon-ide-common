shared interface BuildHook<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared default void repositoryManagerReset(CeylonProjectAlias ceylonProject) {}
    
    "Returns [[true]] if the analysis has been correctly done by the hook,
     or [[false]] if the hook analysis has been cancelled due to
     critical errors that would make the upcoming build impossible or pointless."
    shared default Boolean analyzingChanges(
        {ChangeToAnalyze*} changes,  
        CeylonProjectBuildAlias build, 
        CeylonProjectBuildAlias.State state) => true;
    
    shared default void beforeClasspathResolution(CeylonProjectBuildAlias build, CeylonProjectBuildAlias.State state) {}
    shared default void afterClasspathResolution(CeylonProjectBuildAlias build, CeylonProjectBuildAlias.State state) {}
}