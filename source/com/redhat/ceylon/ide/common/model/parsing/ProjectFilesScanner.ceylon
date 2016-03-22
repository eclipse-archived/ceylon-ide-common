import ceylon.collection {
    MutableMap
}

import com.redhat.ceylon.ide.common.model {
    BaseIdeModule,
    CeylonProject
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

import java.lang.ref {
    WeakReference
}

shared class ProjectFilesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
    CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> ceylonProject,
    FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> rootDir,
    Boolean rootDirIsForSource,
    MutableMap<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> scannedFiles,
    BaseProgressMonitor.Progress progress)
        extends RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
        ceylonProject,
        rootDir,
        progress
    )
        satisfies VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile> 
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    late variable Package currentPackage;

    shared actual Boolean visitNativeResource(NativeResource resource) {
        progress.updateRemainingWork(10000);
        progress.worked(1);
        
        if (resource == nativeRootDir) {
            assert(is NativeFolder resource);
            vfsServices.setPackagePropertyForNativeFolder(ceylonProject, resource, WeakReference(modelLoader.findPackage("")));
            vfsServices.setRootPropertyForNativeFolder(ceylonProject, resource, WeakReference(rootDir));
            vfsServices.setRootIsSourceProperty(ceylonProject, resource, rootDirIsForSource);
            return true;
        }
        
        if (exists parent = vfsServices.getParent(resource),
            parent == nativeRootDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
            currentPackage = modelLoader.findPackage("");
        }
        

        NativeFolder pkgFolder;
        if (vfsServices.isFolder(resource)) {
            pkgFolder = unsafeCast<NativeFolder>(resource);
        } else {
            assert(exists parent = vfsServices.getParent(resource));
            pkgFolder = parent;
        }
        
        value pkgName = vfsServices.toPackageName(pkgFolder, nativeRootDir);
        value pkgNameAsString = ".".join(pkgName);
                
        if (currentModule != defaultModule) {
            if (!pkgNameAsString.startsWith(currentModule.nameAsString + ".")) {
                // We've ran above the last module => reset module to default
                currentModule = defaultModule;
            }
        }

        if (exists realModule = modelLoader.getLoadedModule(pkgNameAsString, null)) {
            assert(is BaseIdeModule realModule);    
            currentModule = realModule;
        }

        currentPackage = modelLoader.findOrCreatePackage(currentModule, pkgNameAsString);
        

        if (vfsServices.isFolder(resource)) {
            assert(is NativeFolder folder=resource);
            vfsServices.setPackagePropertyForNativeFolder(ceylonProject, folder, WeakReference(currentPackage));
            vfsServices.setRootPropertyForNativeFolder(ceylonProject, folder, WeakReference(rootDir));
            return true;
        } else {
            assert(is NativeFile file=resource);
            if (vfsServices.existsOnDisk(resource)) {
                if (ceylonProject.isCompilable(file) || 
                    ! rootDirIsForSource) {
                    FileVirtualFileAlias virtualFile = vfsServices.createVirtualFile(file, ceylonProject.ideArtifact);
                    scannedFiles.put(file, virtualFile);
                    
                    if (rootDirIsForSource && 
                        ceylonProject.isCeylon(file)) {
                        try {
                            value newPhasedUnit = parser(
                                virtualFile
                            ).parseFileToPhasedUnit(moduleManager, typeChecker, virtualFile, rootDir, currentPackage);
                            
                            typeChecker.phasedUnits.addPhasedUnit(virtualFile, newPhasedUnit);
                        } 
                        catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                }
                
                // TODO check if file is compilable + in source folder 
                // TODO add it in the list of scanned files
                // TODO ................. in ResourceVirtualFile add the rootFolder, rootType, and ceylonPackage members.
                // TODO .................. and here add the session properties + impls in IntelliJ and Eclipse
                // TODO And in CeylonBuilder deprecate the corresponding methods and make them call the methods on the ResourceVirtualFile
                // TODO And also in the list of files per project, add FileVritualFile objects.
                // TODO factorize the common logic between ModulesScanner and RootFolderScanner inside ResourceTreeVisitor
                // TODO Rename the visit method to be compatible with the visit throws CoreException method inside Eclipse
            }
        }
        
        return false;
    }
}
