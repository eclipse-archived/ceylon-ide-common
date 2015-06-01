import ceylon.interop.java {
    JavaList,
    javaString
}

import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.loader.model {
    LazyModuleManager
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Package,
    Declaration
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.vfs {
    ResourceVirtualFile,
    FolderVirtualFile,
    FileVirtualFile
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModelLoader() extends AbstractModelLoader() {
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModuleManager() extends LazyModuleManager() {
    shared void addTopLevelModuleError() { throw Exception(); }
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModule() extends Module() {
    shared variable Boolean projectModule = nothing;
    shared {IdeModule*} moduleInReferencingProjects => nothing;
    shared void addedOriginalUnit(String pathRelativeToSrcDir) {}
    shared void removedOriginalUnit(String pathRelativeToSrcDir) {}
}


shared interface ProgressMonitor {
    shared formal variable Integer workRemaining;
    shared formal void worked(Integer amount);
}

shared abstract class ModulesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ceylonProject,
    defaultModule,
    modelLoader,
    moduleManager,
    moduleSourceMapper,
    srcDir,
    typeChecker,
    monitor)
// TODO : Replace this by the CeylonProject, with accessors to retrieve modelLoader, moduleManager, typeChecker, etc...
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    CeylonProject<NativeProject> ceylonProject;
    IdeModule defaultModule;
    IdeModelLoader modelLoader;
    IdeModuleManager moduleManager;
    ModuleSourceMapper moduleSourceMapper;
    FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir;
    TypeChecker typeChecker;
    late variable IdeModule currentModule;
    ProgressMonitor monitor;
    
    alias FolderVirtualFileAlias => FolderVirtualFile<NativeResource, NativeFolder, NativeFile>;
    alias ProjectPhasedUnitAlias => ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>;

    class ModuleDescriptorParser(
        CeylonProject<NativeProject> ceylonProject,
        FileVirtualFile<NativeResource, NativeFolder, NativeFile> moduleFile,
        FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
        IdeModuleManager moduleManager,
        ModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker) extends ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> (
                        ceylonProject,
                        moduleFile,
                        srcDir,
                        moduleManager,
                        moduleSourceMapper,
                        typeChecker) {

        shared actual ProjectPhasedUnitAlias createPhasedUnit(
            Tree.CompilationUnit cu, 
            Package pkg, 
            JList<CommonToken> theTokens)
            => object extends ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
                ceylonProject, 
                moduleFile, 
                outer.srcDir, 
                cu, 
                pkg, 
                moduleManager, 
                moduleSourceMapper,
                outer.typeChecker, 
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
                moduleManager.addTopLevelModuleError();
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
                        srcDir,
                        moduleManager,
                        moduleSourceMapper,
                        typeChecker
                    ).parseFileToPhasedUnit(moduleManager, typeChecker, moduleFile, srcDir, pkg);
                    
                    Module? m = tempPhasedUnit.visitSrcModulePhase();
                    if (exists m) {
                        assert(is IdeModule m);
                        currentModule = m;
                        currentModule.projectModule = true;
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