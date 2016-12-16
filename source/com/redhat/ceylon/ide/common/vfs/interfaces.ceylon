import ceylon.interop.java {
    javaClassFromInstance
}

import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    ModelAliases
}
import com.redhat.ceylon.ide.common.platform {
    VfsServicesConsumer,
    ModelServicesConsumer
}
import com.redhat.ceylon.ide.common.util {
    equalsWithNulls,
    unsafeCast,
    Path
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Module
}

import java.io {
    InputStream,
    File
}
import java.util {
    JList=List,
    Collections
}


shared interface WithParentVirtualFile satisfies VirtualFile {
    shared formal VirtualFile? parent;
}

shared interface BaseResourceVirtualFile
        satisfies WithParentVirtualFile {
    shared actual default Integer hash 
            => path.hash;
    
    shared actual default Boolean equals(Object that)
            => if (is VirtualFile that)
    then that.path == path
    else false;
    
    shared actual Integer compareTo(VirtualFile t)
            => switch(path <=> t.path) 
    case (smaller) -1
    case (equal) 0
    case (larger) 1;
    
    shared actual default String? getRelativePath(VirtualFile ancestor) {
        if (path == ancestor.path) {
            return "";
        }
        value myPath = Path(path);
        value ancestorPath = Path(ancestor.path);
        if (ancestorPath.isPrefixOf(myPath)) {
            return myPath.makeRelativeTo(ancestorPath).string;
        }
        return null;
    }
    
    shared formal actual InputStream? inputStream;
    
    shared formal actual JList<out BaseResourceVirtualFile> children;
    shared actual formal BaseFolderVirtualFile? parent;
    shared default {BaseResourceVirtualFile*} childrenIterable => {*children};
    shared Boolean existsOnDisk => \iexists();
    shared actual default String string => "`` javaClassFromInstance(this).name ``: `` path ``";
}

shared interface ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        of FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        | FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        satisfies BaseResourceVirtualFile
        & ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared formal NativeResource nativeResource;
    shared formal CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>? ceylonProject;

    shared formal NativeProject nativeProject;

    shared formal actual JList<out ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> children;
    shared actual default FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? parent =>
            if (exists folderParent = vfsServices.getParent(nativeResource))
            then vfsServices.createVirtualFolder(folderParent, nativeProject)
            else null;
    
    shared actual default String name => vfsServices.getShortName(nativeResource);
    shared actual default String path => vfsServices.getVirtualFilePathString(nativeResource);
    shared Path? projectRelativePath => 
            if (exists theProject=ceylonProject) 
            then vfsServices.getProjectRelativePath(nativeResource, theProject)
            else null;
    
    shared actual default {ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} childrenIterable => {*children};
    
    shared actual default Boolean \iexists() => vfsServices.existsOnDisk(nativeResource);
    
    shared Boolean isDescendantOfAny({FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} possibleAncestors) =>
            vfsServices.isDescendantOfAny(nativeResource, possibleAncestors.map(FolderVirtualFile.nativeResource));
    
    shared formal FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolder;
    
    shared Path? rootRelativePath => 
            if (exists theRootFolder = rootFolder)
            then Path(path).makeRelativeTo(Path(theRootFolder.path))
            else null;
    
    shared default Boolean? isSource => 
            let (root = rootFolder) 
            if (exists root,
                exists existingProject=ceylonProject)
            then
                if (root == this)
                then vfsServices.getRootIsSourceProperty(existingProject, unsafeCast<NativeFolder>(nativeResource))
                else root.isSource
            else null;

    shared formal Package? ceylonPackage;
    shared Module? ceylonModule => ceylonPackage?.\imodule;
    
    shared File? toJavaFile => vfsServices.getJavaFile(nativeResource);
    
    shared actual default Boolean equals(Object that) => 
            if (is ResourceVirtualFile<out Object,out Object,out Object,out Object> that) 
            then nativeResource == that.nativeResource && 
                    nativeProject == that.nativeProject
            else false;
    
    shared actual default Integer hash {
        variable Integer hash = 1;
        hash = 31*hash + nativeResource.hash;
        hash = 31*hash + nativeProject.hash;
        return hash;
    }
    
    string => "`` javaClassFromInstance(this).name ``: `` nativeResource ``";
}

shared interface BaseFolderVirtualFile
        satisfies BaseResourceVirtualFile {
    shared actual Boolean folder => true;
    shared actual Null inputStream => null;
    shared formal BaseFileVirtualFile? findFile(String fileName);
    shared formal [String*] toPackageName(BaseFolderVirtualFile srcDir);
}

shared interface FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies BaseFolderVirtualFile
        & ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual formal NativeFolder nativeResource;

    shared actual default [String*] toPackageName(BaseFolderVirtualFile srcDir) {
        assert(is FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir);
        return vfsServices.toPackageName(nativeResource, srcDir.nativeResource);
    }

    shared actual default FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>? findFile(String fileName) =>
            if (exists nativeFile = vfsServices.findFile(nativeResource, fileName))
            then vfsServices.createVirtualFile(nativeFile, nativeProject)
            else null;

    shared actual default FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolder {
        if (exists existingProject=ceylonProject) {
            NativeFolder folder = nativeResource;
            if (! vfsServices.existsOnDisk(folder)) {
                Path searchedPath = Path(path);
                return ceylonProject?.rootFolders?.find((aRootFolder) => Path(aRootFolder.path).isPrefixOf(searchedPath));
            }
            return vfsServices.getRootPropertyForNativeFolder(existingProject, folder)?.get();
        } else {
            return null;
        }
    }
    
    shared actual default Package? ceylonPackage {
        if (exists existingProject=ceylonProject) {
            if (! vfsServices.existsOnDisk(nativeResource)) {
                if (exists theRootRelativePath = rootRelativePath) {
                    return existingProject.modelLoader?.findPackage(".".join(theRootRelativePath.segments));
                }
                return null;
            }
            return vfsServices.getPackagePropertyForNativeFolder(existingProject, nativeResource)?.get();
        } else {
            return null;
        }
    }
    
    shared default Boolean isRoot =>
            equalsWithNulls(rootFolder, this);
}

shared interface BaseFileVirtualFile 
        satisfies BaseResourceVirtualFile {
    shared actual formal InputStream inputStream;
    shared formal String? charset;
    shared actual Boolean folder => false;
    shared actual default JList<out BaseResourceVirtualFile> children 
            => Collections.emptyList<BaseFileVirtualFile>();
}

shared interface FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        satisfies ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        & BaseFileVirtualFile 
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    shared actual JList<out ResourceVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> children 
            => Collections.emptyList<FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();
    
    shared actual formal NativeFile nativeResource;
    
    rootFolder => parent?.rootFolder;
    
    shared actual Boolean? isSource => parent?.isSource;

    shared actual Package? ceylonPackage => parent?.ceylonPackage;
    
    shared Boolean sourceFile 
            => (isSource else false)
            && (ceylonProject?.isCompilable(nativeResource) else false);
    
    shared Boolean resourceFile 
            => if (exists isInSourceFolder = isSource) 
            then !isInSourceFolder 
            else false;
    
    shared ModifiableSourceFileAlias|JavaUnitAlias? unit {
        if (exists pack = ceylonPackage) {
            // Go through `members` since the units of Java files are added lazily in the Package.
            // `members` loads all the declarations eagerly, making the units of Java files visible
            for (dec in pack.members) {
                if (is ModifiableSourceFileAlias|JavaUnitAlias unit = dec.unit,
                    unit.filename == name) {
                    return unit;
                }
            }
            else {
                return null;
            }
        }
        else {
            return null;
        }
    }
}
