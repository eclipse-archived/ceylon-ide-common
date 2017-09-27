import org.eclipse.ceylon.compiler.typechecker {
    TypeChecker
}
import org.eclipse.ceylon.ide.common.model {
    BaseIdeModelLoader,
    BaseIdeModuleSourceMapper,
    BaseIdeModule,
    ModelAliases,
    BaseIdeModuleManager
}
import org.eclipse.ceylon.ide.common.util {
    BaseProgressMonitor
}
import org.eclipse.ceylon.ide.common.vfs {
    VfsAliases
}
import org.eclipse.ceylon.ide.common.platform {
    VfsServicesConsumer
}

shared abstract class RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(
            ceylonProject,
            rootDir,
            progress) 
        satisfies VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
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
    shared FolderVirtualFileAlias rootDir;
    shared TypeChecker typeChecker = moduleManager.typeChecker;
    shared late variable BaseIdeModule currentModule;
    shared BaseProgressMonitor.Progress progress;
    shared NativeFolder nativeRootDir = rootDir.nativeResource;
    
    shared default ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> parser(
        FileVirtualFileAlias sourceFile) 
            => ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile> (
                    ceylonProject,
                    sourceFile,
                    rootDir);
            
    shared formal Boolean visitNativeResource(NativeResource resource);
}