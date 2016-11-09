import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}

shared final class ResourceChangeType 
        of fileContentChange 
        | fileAddition
        | fileRemoval
        | folderAddition
        | folderRemoval
{
    shared new fileContentChange {}
    shared new fileAddition {}
    shared new fileRemoval {}
    shared new folderAddition {}
    shared new folderRemoval {}
}

shared abstract class ResourceChange<Resource, Folder, File>()
        of FolderChange<Resource, Folder, File>
        | FileChange<Resource, Folder, File> 
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    shared formal ResourceChangeType type;
    shared formal Resource resource;
    
    shared actual Boolean equals(Object that) => 
            if (is ResourceChange<out Object, out Object, out Object> that) 
    then type==that.type && 
            resource==that.resource 
    else false;
    
    shared actual Integer hash {
            variable value hash = 1;
            hash = 31*hash + type.hash;
            hash = 31*hash + resource.hash;
            return hash;
        }
}

shared abstract class FileChange<Resource, Folder, File>(File theFile)
        of FileContentChange<Resource, Folder, File>
        | FileAddition<Resource, Folder, File> 
        | FileRemoval<Resource, Folder, File>
        extends ResourceChange<Resource, Folder, File>()
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    shared actual File resource = theFile;
}

shared class FileContentChange<Resource, Folder, File>(File theFile)
        extends FileChange<Resource, Folder, File>(theFile)
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    type = ResourceChangeType.fileContentChange;
}

shared class FileAddition<Resource, Folder, File>(File theFile)
        extends FileChange<Resource, Folder, File>(theFile)
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    type = ResourceChangeType.fileAddition;
}

shared class FileRemoval<Resource, Folder, File>(
    File theFile,
    "if [[theFile]] has been removed after a move or rename,
     this indicates the new file to which [[theFile]] has been moved or renamed."
    shared File? movedTo)
        extends FileChange<Resource, Folder, File>(theFile)
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    type = ResourceChangeType.fileRemoval;
}

shared abstract class FolderChange<Resource, Folder, File>(Folder theFolder)
        of FolderAddition<Resource, Folder, File>
        | FolderRemoval<Resource, Folder, File>
        extends ResourceChange<Resource, Folder, File>()
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    shared actual Folder resource = theFolder;
}

shared class FolderAddition<Resource, Folder, File>(Folder theFolder)
        extends FolderChange<Resource, Folder, File>(theFolder)
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    type = ResourceChangeType.folderAddition;
}

shared class FolderRemoval<Resource, Folder, File>(
    Folder theFolder,
    "if [[theFolder]] has been removed after a move or rename,
     this indicates the new file to which [[theFolder]] has been moved or renamed."
    shared Folder? movedTo)
        extends FolderChange<Resource, Folder, File>(theFolder)
        given Resource satisfies Object 
        given Folder satisfies Resource 
        given File satisfies Resource {
    type = ResourceChangeType.folderRemoval;
}

shared interface ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    shared alias NativeResourceChange => ResourceChange<NativeResource, NativeFolder, NativeFile>;
    shared alias NativeFileChange => FileChange<NativeResource, NativeFolder, NativeFile>;
    shared class NativeFileContentChange(NativeFile theFile) => FileContentChange<NativeResource, NativeFolder, NativeFile>(theFile);
    shared class NativeFileAddition(NativeFile theFile) => FileAddition<NativeResource, NativeFolder, NativeFile>(theFile);
    shared class NativeFileRemoval(NativeFile theFile, NativeFile? movedTo) => FileRemoval<NativeResource, NativeFolder, NativeFile>(theFile, movedTo);
    shared alias NativeFolderChange => FolderChange<NativeResource, NativeFolder, NativeFile>;
    shared class NativeFolderAddition(NativeFolder theFolder) => FolderAddition<NativeResource, NativeFolder, NativeFile>(theFolder);
    shared class NativeFolderRemoval(NativeFolder theFolder, NativeFolder? movedTo) => FolderRemoval<NativeResource, NativeFolder, NativeFile>(theFolder, movedTo);
    
    shared alias ResourceVirtualFileChange => ResourceChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared alias FileVirtualFileChange => FileChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared class FileVirtualFileContentChange(FileVirtualFileAlias theFile) => FileContentChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile);
    shared class FileVirtualFileAddition(FileVirtualFileAlias theFile) => FileAddition<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile);
    shared class FileVirtualFileRemoval(FileVirtualFileAlias theFile, FileVirtualFileAlias? movedTo) => FileRemoval<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFile, movedTo);
    shared alias FolderVirtualFileChange => FolderChange<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>;
    shared class FolderVirtualFileAddition(FolderVirtualFileAlias theFolder) => FolderAddition<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFolder);
    shared class FolderVirtualFileRemoval(FolderVirtualFileAlias theFolder, FolderVirtualFileAlias? movedTo) => FolderRemoval<ResourceVirtualFileAlias, FolderVirtualFileAlias, FileVirtualFileAlias>(theFolder, movedTo);

    shared alias ChangeToAnalyze
        => [NativeResourceChange, NativeProject]
         | ResourceVirtualFileChange;
        
    shared alias ChangeToConvert
        => [NativeFolderChange, FolderVirtualFileAlias?(NativeFolder)]
         | [NativeFileChange,FileVirtualFileAlias?(NativeFile)];
    
    shared ResourceVirtualFileChange? toProjectChange(ChangeToConvert changeToConvert) { 
        switch(changeToConvert)
        case (is [NativeFileChange,FileVirtualFileAlias?(NativeFile)]) {
            value [change, convert] = changeToConvert;
            switch (change)
            case(is NativeFileContentChange) {
                return ifExists(convert(change.resource), FileVirtualFileContentChange);
            }
            case(is NativeFileAddition) {
                return ifExists(convert(change.resource), FileVirtualFileAddition);
            }
            case(is NativeFileRemoval) {
                return ifExists(convert(change.resource), 
                    (FileVirtualFileAlias vf)
                        => FileVirtualFileRemoval(vf,
                            if (exists movedTo = change.movedTo)
                            then convert(movedTo)
                            else null));
            }
        }
        case (is [NativeFolderChange, FolderVirtualFileAlias?(NativeFolder)]) {
            value [change, convert] = changeToConvert;
            switch(change)
            case(is NativeFolderAddition) {
                return ifExists(convert(change.resource), FolderVirtualFileAddition);
            }
            case(is NativeFolderRemoval) {
                return ifExists(convert(change.resource), 
                    (FolderVirtualFileAlias vf)
                        => FolderVirtualFileRemoval(vf,
                            if (exists movedTo = change.movedTo)
                            then convert(movedTo)
                            else null));
            }
        }
    }

    Result? ifExists<Result,Param>(Param? p, Result(Param) f) =>
            if (exists p) then f(p) else null;

}

