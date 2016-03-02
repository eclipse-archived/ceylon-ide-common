import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.ide.common.model {
    ModelAliases,
    BaseIdeModule,
    CeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    VfsAliases,
    FileVirtualFile
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
    MutableList<FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> scannedFiles,
    BaseProgressMonitor monitor)
        extends RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
        ceylonProject,
        rootDir,
        monitor
    )
        satisfies ModelAliases<NativeProject,NativeResource,NativeFolder,NativeFile>
            & TypecheckerAliases<NativeProject,NativeResource,NativeFolder,NativeFile>
            & VfsAliases<NativeProject,NativeResource,NativeFolder,NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    late variable Package currentPackage;

    shared actual Boolean visitNativeResource(NativeResource resource) {
        monitor.updateRemainingWork(10000);
        monitor.worked(1);
        
        if (resource == nativeRootDir) {
            assert(is NativeFolder resource);
            ceylonProject.setPackageForNativeFolder(resource, WeakReference(modelLoader.findPackage("")));
            ceylonProject.setRootForNativeFolder(resource, WeakReference(rootDir));
            ceylonProject.setRootIsForSource(resource, rootDirIsForSource);
            return true;
        }
        
        if (exists parent = vfs.getParent(resource),
            parent == nativeRootDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
            currentPackage = modelLoader.findPackage("");
        }
        

        NativeFolder pkgFolder;
        if (vfs.isFolder(resource)) {
            pkgFolder = unsafeCast<NativeFolder>(resource);
        } else {
            assert(exists parent = vfs.getParent(resource));
            pkgFolder = parent;
        }
        
        value pkgName = vfs.toPackageName(pkgFolder, nativeRootDir);
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
        

        if (vfs.isFolder(resource)) {
            assert(is NativeFolder folder=resource);
            ceylonProject.setPackageForNativeFolder(folder, WeakReference(currentPackage));
            ceylonProject.setRootForNativeFolder(folder, WeakReference(rootDir));
            return true;
        } else {
            assert(is NativeFile file=resource);
            if (vfs.existsOnDisk(resource)) {
                if (ceylonProject.isCompilable(file) || 
                    ! rootDirIsForSource) {
                    FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> virtualFile = vfs.createVirtualFile(file, ceylonProject.ideArtifact);
                    scannedFiles.add(virtualFile);
                    
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
