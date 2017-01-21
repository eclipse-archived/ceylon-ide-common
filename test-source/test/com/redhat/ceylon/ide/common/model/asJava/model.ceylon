import com.redhat.ceylon.compiler.typechecker.context {
    Context
}
import com.redhat.ceylon.compiler.typechecker.util {
    ModuleManagerFactory
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    CeylonProjects,
    ModelAliases
}
import com.redhat.ceylon.ide.common.model.parsing {
    RootFolderScanner
}
import com.redhat.ceylon.ide.common.platform {
    ModelServices,
    VfsServices
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitorChild,
    Path
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    File
}
import java.lang.ref {
    WeakReference
}

suppressWarnings("expressionTypeNothing")
shared object vfsServices
        satisfies VfsServices<DummyProject,File,File,File> {
    shared actual VfsAliases<DummyProject,File,File,File>.FileVirtualFileAlias createVirtualFile(File file, DummyProject project) => nothing;
    
    shared actual VfsAliases<DummyProject,File,File,File>.FileVirtualFileAlias createVirtualFileFromProject(DummyProject project, Path path) => nothing;
    
    shared actual VfsAliases<DummyProject,File,File,File>.FolderVirtualFileAlias createVirtualFolder(File folder, DummyProject project) => nothing;
    
    shared actual VfsAliases<DummyProject,File,File,File>.FolderVirtualFileAlias createVirtualFolderFromProject(DummyProject project, Path path) => nothing;
    
    shared actual Boolean existsOnDisk(File resource) => nothing;
    
    shared actual File? findChild(File|DummyProject parent, Path path) => nothing;
    
    shared actual File? findFile(File resource, String fileName) => nothing;
    
    shared actual Boolean flushIfNecessary(File resource) => nothing;
    
    shared actual File? fromJavaFile(File javaFile, DummyProject project) => javaFile;
    
    shared actual File? getJavaFile(File resource) => nothing;
    
    shared actual WeakReference<Package>? getPackagePropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder) => nothing;
    
    shared actual File? getParent(File resource) => nothing;
    
    shared actual Path? getProjectRelativePath(File resource, ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias|DummyProject project) => nothing;
    
    shared actual String? getProjectRelativePathString(File resource, ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias|DummyProject project) => nothing;
    
    shared actual Boolean? getRootIsSourceProperty(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File rootFolder) => nothing;
    
    shared actual WeakReference<VfsAliases<DummyProject,File,File,File>.FolderVirtualFileAlias>? getRootPropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder) => nothing;
    
    shared actual String getShortName(File resource) => nothing;
    
    shared actual Path getVirtualFilePath(File resource) => nothing;
    
    shared actual String getVirtualFilePathString(File resource) => nothing;
    
    shared actual Boolean isFolder(File resource) => nothing;
    
    shared actual void removePackagePropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder) {}
    
    shared actual void removeRootIsSourceProperty(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File rootFolder) {}
    
    shared actual void removeRootPropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder) {}
    
    shared actual void setPackagePropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder, WeakReference<Package> p) {}
    
    shared actual void setRootIsSourceProperty(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File rootFolder, Boolean isSource) {}
    
    shared actual void setRootPropertyForNativeFolder(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject, File folder, WeakReference<VfsAliases<DummyProject,File,File,File>.FolderVirtualFileAlias> root) {}
    
    shared actual String[] toPackageName(File resource, File sourceDir) => nothing;
    
}

suppressWarnings("expressionTypeNothing")
shared object modelServices
        satisfies ModelServices<DummyProject,File,File,File> {
    
    isResourceContainedInProject(File resource, ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject) => 
            ceylonProject.rootDirectory.absolutePath in resource.absolutePath;
    nativeProjectIsAccessible(DummyProject nativeProject) => nativeProject.root.\iexists();
    newCrossProjectSourceFile(TypecheckerAliases<DummyProject,File,File,File>.CrossProjectPhasedUnitAlias phasedUnit) => nothing;
    newEditedSourceFile(TypecheckerAliases<DummyProject,File,File,File>.EditedPhasedUnitAlias phasedUnit) => nothing;
    newProjectSourceFile(TypecheckerAliases<DummyProject,File,File,File>.ProjectPhasedUnitAlias phasedUnit) => nothing;
    referencedNativeProjects(DummyProject nativeProject) => {};
    referencingNativeProjects(DummyProject nativeProject) => {};
    resourceNativeFolders(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject) => {};
    scanRootFolder(RootFolderScanner<DummyProject,File,File,File> scanner) => noop();
    sourceNativeFolders(ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias ceylonProject) => {};
}

shared class DummyProject(shared File root, shared File distRepo, shared Boolean loadFromBinaries, shared String name = "dummy") {    
}

shared class DummyCeylonProject(ideArtifact) extends CeylonProject<DummyProject, File, File, File>() {
    shared actual DummyProject ideArtifact;
    shared actual Boolean compileToJava => true;
    shared actual Boolean compileToJs => false;
    
    shared actual void completeCeylonModelParsing(BaseProgressMonitorChild monitor) {}
    shared actual void createNewOutputFolder(String folderProjectRelativePath) {}
    shared actual void createOverridesProblemMarker(Exception theOverridesException, File absoluteFile, Integer overridesLine, Integer overridesColumn) {}
    shared actual void deleteOldOutputFolder(String folderProjectRelativePath) {}
    
    shared actual Boolean hasConfigFile => false;
    shared actual void refreshConfigFile(String projectRelativePath) {}
    shared actual void removeOverridesProblemMarker() {}
    shared actual Boolean synchronizedWithConfiguration => true;
    shared actual String systemRepository => ideArtifact.distRepo.absolutePath;
    
    shared actual ModelAliases<DummyProject,File,File,File>.CeylonProjectsAlias model => dummyModel;
    
    suppressWarnings("expressionTypeNothing")
    shared actual ModuleManagerFactory moduleManagerFactory => object satisfies ModuleManagerFactory{
        createModuleManager(Context? context) => DummyModuleManager(outer);
        createModuleManagerUtil(Context context, ModuleManager moduleManager) => if (is DummyModuleManager moduleManager)
        then DummyModuleSourceMapper(context, moduleManager)
        else nothing;
    };
    
    name => ideArtifact.name;
    rootDirectory => ideArtifact.root;
    shared actual DummyModelLoader? modelLoader {
        assert(is DummyModelLoader dummy = super.modelLoader);
        return dummy;
    }
}

shared object dummyModel extends CeylonProjects<DummyProject, File, File, File>() {
    shared actual ModelAliases<DummyProject,File,File,File>.CeylonProjectAlias newNativeProject(DummyProject nativeProject) =>
            DummyCeylonProject(nativeProject);
}
