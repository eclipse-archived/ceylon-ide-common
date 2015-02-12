/*

shared interface IResource {}
shared interface IFolder satisfies IResource {}
shared interface IFile satisfies IResource {}

shared class IFolderVirtualFile(nativeResource) 
        satisfies FolderVirtualFile<IResource, IFolder, IFile> {
    shared actual IFolder nativeResource;
    shared actual IFolderVirtualFile? parent
            => if (is IFolder folderParent = nativeResource.parent)
                    then IFolderVirtualFile(folderParent)
                    else null;
    shared actual FileVirtualFile<IResource,IFolder,IFile>? findFile(String fileName)
            => if (exists nativeFile = nativeResource.getFile(fileName))
                    then IFileVirtualFile(nativeFile)
                    else null;
    shared actual JList<out ResourceVirtualFile<IResource, IFolder, IFile>> children => nothing;
    shared actual String name => nothing;
    shared actual String path => nothing;
    shared actual Boolean equals(Object that)
            => (super of FolderVirtualFile<IResource, IFolder, IFile>).equals(that);
    shared actual Integer hash
            => (super of FolderVirtualFile<IResource, IFolder, IFile>).hash;
    
    shared actual [String*] toPackageName(FolderVirtualFile<IResource, IFolder, IFile> srcDir) {
        assert(is IFolderVirtualFile srcDir);
        return toStringArray(nativeResource.projectRelativePath
            .makeRelativeTo(srcDir.nativeResource.projectRelativePath)
                .segments()).coalesced.sequence();
    }
}

shared class IFileVirtualFile(nativeResource)
        satisfies FileVirtualFile<IResource, IFolder, IFile> {
    shared actual IFile nativeResource;
    shared actual IFolderVirtualFile? parent
            => if (is IFolder folderParent = nativeResource.parent)
                    then IFolderVirtualFile(folderParent)
                    else null;
    
    shared actual Boolean equals(Object that)
            => (super of FileVirtualFile<IResource, IFolder, IFile>).equals(that);
    shared actual Integer hash
            => (super of FileVirtualFile<IResource, IFolder, IFile>).hash;
    shared actual InputStream? inputStream => nothing;
    shared actual String name => nothing;
    shared actual String path => nothing;
    shared actual String charset {
        try {
            return nativeResource.project.defaultCharset; // in the future, we could return the charset of the file
        }
        catch (Exception e) {
            throw RuntimeException(e);
        }

    }
}

 */
 
