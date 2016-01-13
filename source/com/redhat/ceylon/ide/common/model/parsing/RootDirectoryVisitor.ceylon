import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.ide.common.model {
    BaseIdeModelLoader,
    BaseIdeModuleSourceMapper,
    BaseIdeModule,
    CeylonProjects,
    ModelAliases,
    BaseIdeModuleManager
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    VfsAliases
}

shared abstract class RootDirectoryVisitor<NativeProject, NativeResource, NativeFolder, NativeFile>(
            ceylonProject,
            rootDir,
            monitor) 
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile> 
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared CeylonProjectAlias ceylonProject;
    assert(exists modules=ceylonProject.modules);
    shared BaseIdeModule defaultModule = modules.default;
    shared BaseIdeModuleManager moduleManager = modules.manager;
    shared BaseIdeModuleSourceMapper moduleSourceMapper = modules.sourceMapper;
    shared BaseIdeModelLoader modelLoader = moduleManager.modelLoader;
    shared FolderVirtualFile<NativeProject,NativeResource, NativeFolder, NativeFile> rootDir;
    shared TypeChecker typeChecker = moduleManager.typeChecker;
    shared late variable BaseIdeModule currentModule;
    shared BaseProgressMonitor monitor;
    shared NativeFolder nativeRootDir = rootDir.nativeResource;
    shared CeylonProjects<NativeProject, NativeResource, NativeFolder, NativeFile>.VirtualFileSystem vfs => ceylonProject.model.vfs;
    
    shared default ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> parser(
        FileVirtualFileAlias sourceFile) 
            => ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> (
                    ceylonProject,
                    sourceFile,
                    rootDir);
            
    shared formal Boolean visitNativeResource(NativeResource resource);
}