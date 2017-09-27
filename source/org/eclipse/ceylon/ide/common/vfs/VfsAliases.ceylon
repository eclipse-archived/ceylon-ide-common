shared interface VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared alias FolderVirtualFileAlias => FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias FileVirtualFileAlias => FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias ResourceVirtualFileAlias => ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>;
}