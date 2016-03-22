import com.redhat.ceylon.ide.common.platform {
    VfsServices,
    platformServices
}

shared interface VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile> {
    shared VfsServices<NativeProject, NativeResource, NativeFolder, NativeFile> vfsServices =>
            platformServices.vfs<NativeProject, NativeResource, NativeFolder, NativeFile>();
}