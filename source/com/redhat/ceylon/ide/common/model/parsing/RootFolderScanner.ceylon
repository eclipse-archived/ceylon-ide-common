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
    BaseIdeModule
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
    ceylonProject,
    srcDir,
    monitor)
        satisfies ModelAliases<NativeProject,NativeResource,NativeFolder,NativeFile>
            & TypecheckerAliases<NativeProject,NativeResource,NativeFolder,NativeFile>
            & VfsAliases<NativeResource,NativeFolder,NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    CeylonProjectAlias ceylonProject;
    assert (exists modules = ceylonProject.modules);
    BaseIdeModule defaultModule = modules.default;
    BaseIdeModuleManager moduleManager = modules.manager;
    BaseIdeModuleSourceMapper moduleSourceMapper = modules.sourceMapper;
    BaseIdeModelLoader modelLoader = moduleManager.modelLoader;
    FolderVirtualFile<NativeResource,NativeFolder,NativeFile> srcDir;
    TypeChecker typeChecker = moduleManager.typeChecker;
    late variable BaseIdeModule currentModule;
    BaseProgressMonitor monitor;
    late variable Package currentPackage;
    
    class CeylonUnitParser(
        CeylonProjectAlias theCeylonProject,
        FileVirtualFileAlias moduleFile,
        FolderVirtualFileAlias srcDir) extends ProjectSourceParser<NativeProject,NativeResource,NativeFolder,NativeFile>(
        theCeylonProject,
        moduleFile,
        srcDir) {
        
        shared actual ProjectPhasedUnitAlias createPhasedUnit(
            Tree.CompilationUnit cu,
            Package pkg,
            JList<CommonToken> theTokens)
                => ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile>(
            theCeylonProject,
            moduleFile,
            outer.srcDir,
            cu,
            pkg,
            moduleManager,
            moduleSourceMapper,
            moduleManager.typeChecker,
            theTokens);
    }
    
    shared Boolean visit(ResourceVirtualFile<NativeResource,NativeFolder,NativeFile> resource) {
        monitor.workRemaining = 10000;
        monitor.worked(1);
        
        if (is FolderVirtualFileAlias resource, resource == srcDir) {
            return true;
        }
        
        if (exists parent = resource.parent, parent == srcDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
            currentPackage = modelLoader.findPackage("");
        }
        
        if (is FolderVirtualFileAlias resource) {
            value pkgName = resource.toPackageName(srcDir);
            value pkgNameAsString = ".".join(pkgName);
            
            if (currentModule != defaultModule) {
                if (!pkgNameAsString.startsWith(currentModule.nameAsString + ".")) {
                    // We've ran above the last module => reset module to default
                    currentModule = defaultModule;
                }
            }
            
            if (exists moduleFile = resource.findFile(ModuleManager.\iMODULE_FILE)) {
                value m = modelLoader.getLoadedModule(pkgNameAsString, null);
                assert (is BaseIdeModule m);
                currentModule = m;
            }
            
            currentPackage = modelLoader.findOrCreatePackage(currentModule, pkgNameAsString);
            
            return true;
        } else if (resource.\iexists()) {
            // TODO check if file is compilable + in source folder
            value pu = CeylonUnitParser(
                ceylonProject,
                resource,
                srcDir
            ).parseFileToPhasedUnit(moduleManager, typeChecker, resource, srcDir, currentPackage);
            
            typeChecker.phasedUnits.addPhasedUnit(resource, pu);
        }
        
        return false;
    }
}
