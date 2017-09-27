shared interface IResourceAware<NativeProject, NativeFolder, NativeFile> {
    shared formal NativeFolder? resourceRootFolder;
    shared formal NativeFile? resourceFile;
    shared formal NativeProject? resourceProject;
}
