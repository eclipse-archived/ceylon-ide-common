import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    ModelAliases,
    BaseIdeModelLoader,
    BaseIdeModuleManager,
    BaseIdeModuleSourceMapper,
    BaseIdeModule,
    CeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases,
    ProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
    ProjectSourceParser
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    VfsAliases,
    ResourceVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
    CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> ceylonProject,
    FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir,
    BaseProgressMonitor monitor)
        extends SourceDirectoryVisitor<NativeProject, NativeResource, NativeFolder, NativeFile>(
        ceylonProject,
        srcDir,
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

    shared Boolean visit(NativeResource resource) {
        monitor.workRemaining = 10000;
        monitor.worked(1);
        
        if (resource == nativeSourceDir) {
            return true;
        }
        
        if (exists parent = vfs.getParent(resource),
            parent == nativeSourceDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
            currentPackage = modelLoader.findPackage("");
        }
        
        if (vfs.isFolder(resource)) {
            assert(is NativeFolder resource);
            value pkgName = vfs.toPackageName(resource, nativeSourceDir);
            value pkgNameAsString = ".".join(pkgName);
            
            if (currentModule != defaultModule) {
                if (!pkgNameAsString.startsWith(currentModule.nameAsString + ".")) {
                    // We've ran above the last module => reset module to default
                    currentModule = defaultModule;
                }
            }
            
            if (exists moduleFile = vfs.findFile(resource, ModuleManager.\iMODULE_FILE)) {
                value m = modelLoader.getLoadedModule(pkgNameAsString, null);
                assert (is BaseIdeModule m);
                currentModule = m;
            }
            
            currentPackage = modelLoader.findOrCreatePackage(currentModule, pkgNameAsString);
            
            return true;
        } else {
            assert(is NativeFile resource);
            if (vfs.existsOnDisk(resource)) {
                // TODO check if file is compilable + in source folder 
                // TODO add it in the list of scanned files
                // TODO ................. in ResourceVirtualFile add the rootFolder, rootType, and ceylonPackage members.
                // TODO .................. and here add the session properties + impls in IntelliJ and Eclipse
                // TODO And in CeylonBuilder deprecate the corresponding methods and make them call the methods on the ResourceVirtualFile
                // TODO And also in the list of files per project, add FileVritualFile objects.
                // TODO factorize the common logic between ModulesScanner and RootFolderScanner inside ResourceTreeVisitor
                // TODO Rename the visit method to be compatible with the visit throws CoreException method inside Eclipse
                
                value sourceVirtualFile = ceylonProject.model.vfs.createVirtualFile(resource);
                value pu = parser(
                    sourceVirtualFile
                ).parseFileToPhasedUnit(moduleManager, typeChecker, sourceVirtualFile, srcDir, currentPackage);
                
                typeChecker.phasedUnits.addPhasedUnit(sourceVirtualFile, pu);
            }
        }
        
        return false;
    }
}
