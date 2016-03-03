shared interface ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared formal void modelParsed(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project);
}