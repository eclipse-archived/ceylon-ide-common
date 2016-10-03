

shared interface ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile> {
    shared ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile> modelServices =>
            platformServices.model<NativeProject, NativeResource, NativeFolder, NativeFile>();
}