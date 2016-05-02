shared interface ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared alias CeylonProjectAlias => CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias CeylonProjectBuildAlias => CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias BuildHookAlias => BuildHook<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias CeylonProjectsAlias => CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>;

    shared alias IdeModuleAlias => IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>;

    shared alias EditedSourceFileAlias => EditedSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias ModifiableSourceFileAlias => ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias ProjectSourceFileAlias => ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias CrossProjectSourceFileAlias => CrossProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias IResourceAwareAlias => IResourceAware<NativeProject, NativeFolder, NativeFile>;
    shared alias BaseJavaUnitAlias => BaseJavaUnit<NativeProject, NativeFolder, NativeFile>;
    shared alias ICrossProjectReferenceAlias => ICrossProjectReference<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias CeylonBinaryUnitAlias => CeylonBinaryUnit<NativeProject, NativeFolder, NativeFile>;
        

    shared alias IdeModuleManagerAlias => IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias IdeModuleSourceMapperAlias => IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>;
}