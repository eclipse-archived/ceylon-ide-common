shared interface VfsAliases<NativeResource, NativeFolder, NativeFile>
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared alias FolderVirtualFileAlias => FolderVirtualFile<NativeResource, NativeFolder, NativeFile>;
    shared alias FileVirtualFileAlias => FileVirtualFile<NativeResource, NativeFolder, NativeFile>;
    shared alias ResourceVirtualFileAlias => ResourceVirtualFile<NativeResource, NativeFolder, NativeFile>;
}