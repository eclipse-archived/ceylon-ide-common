import ceylon.interop.java {
    JavaList,
    javaString
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    IdeModelLoader,
    BaseIdeModule,
    BaseIdeModuleManager,
    BaseIdeModuleSourceMapper,
    ModelAliases
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    ProgressMonitor,
    ProjectSourceParser
}
import com.redhat.ceylon.ide.common.vfs {
    ResourceVirtualFile,
    FolderVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Package,
    Declaration
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

shared abstract class ModulesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
            ceylonProject,
            srcDir,
            monitor)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    CeylonProjectAlias ceylonProject;
    assert(exists modules=ceylonProject.modules);
    BaseIdeModule defaultModule = modules.default;
    BaseIdeModuleManager moduleManager = modules.manager;
    BaseIdeModuleSourceMapper moduleSourceMapper = modules.sourceMapper;
    IdeModelLoader modelLoader = moduleManager.modelLoader;
    FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir;
    TypeChecker typeChecker = moduleManager.typeChecker;
    late variable BaseIdeModule currentModule;
    ProgressMonitor monitor;


    class ModuleDescriptorParser(
        CeylonProjectAlias theCeylonProject,
        FileVirtualFileAlias moduleFile,
        FolderVirtualFileAlias srcDir
    ) extends ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> (
                        theCeylonProject,
                        moduleFile,
                        srcDir) {

        shared actual ProjectPhasedUnitAlias createPhasedUnit(
            Tree.CompilationUnit cu,
            Package pkg,
            JList<CommonToken> theTokens)
            => object extends ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
                theCeylonProject,
                moduleFile,
                outer.srcDir,
                cu,
                pkg,
                moduleManager,
                moduleSourceMapper,
                moduleManager.typeChecker,
                theTokens) {

                shared actual Boolean isAllowedToChangeModel(Declaration? declaration) => false;
            };
    }

    shared Boolean visit(ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> resource) {
        monitor.workRemaining = 10000;
        monitor.worked(1);
        if (is FolderVirtualFileAlias resource,
            resource == srcDir) {
            value moduleFile = resource.findFile(ModuleManager.\iMODULE_FILE);
            if (exists moduleFile) {
                moduleSourceMapper.addTopLevelModuleError();
            }
            return true;
        }

        if (exists parent = resource.parent,
            parent == srcDir) {
            // We've come back to a source directory child :
            //  => reset the current Module to default and set the package to emptyPackage
            currentModule = defaultModule;
        }

        if (is FolderVirtualFileAlias resource) {
            value pkgName = resource.toPackageName(srcDir);
            value pkgNameAsString = ".".join(pkgName);

            if ( currentModule != defaultModule ) {
                if (! pkgNameAsString.startsWith(currentModule.nameAsString + ".")) {
                    // We've ran above the last module => reset module to default
                    currentModule = defaultModule;
                }
            }

            value moduleFile = resource.findFile(ModuleManager.\iMODULE_FILE);
            if (exists moduleFile) {
                // First create the package with the default module and we'll change the package
                // after since the module doesn't exist for the moment and the package is necessary
                // to create the PhasedUnit which in turns is necessary to create the module with the
                // right version from the beginning (which is necessary now because the version is
                // part of the Module signature used in equals/has methods and in caching
                // The right module will be set when calling findOrCreatePackage() with the right module
                value pkg = Package();

                pkg.name = JavaList(pkgName.map((String s)=> javaString(s)).sequence());

                try {
                    value tempPhasedUnit = ModuleDescriptorParser(
                        ceylonProject,
                        moduleFile,
                        srcDir
                    ).parseFileToPhasedUnit(moduleManager, typeChecker, moduleFile, srcDir, pkg);

                    Module? m = tempPhasedUnit.visitSrcModulePhase();
                    if (exists m) {
                        assert(is BaseIdeModule m);
                        currentModule = m;
                        currentModule.isProjectModule = true;
                    }
                }
                catch (Exception e) {
                    e.printStackTrace();
                }
            }

            if (currentModule != defaultModule) {
                // Creates a package with this module only if it's not the default
                // => only if it's a *ceylon* module
                modelLoader.findOrCreatePackage(currentModule, pkgNameAsString);
            }
            return true;
        }
        return false;
    }
}