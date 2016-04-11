import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    IResourceAware,
    ModelAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    FileVirtualFile,
    FolderVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends IdePhasedUnit
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
        & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    shared new (
        FileVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> unitFile, 
        FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> srcDir, 
        Tree.CompilationUnit cu, Package p, ModuleManager moduleManager, 
        ModuleSourceMapper moduleSourceMapper, 
        TypeChecker typeChecker, 
        List<CommonToken> tokenStream)
            extends IdePhasedUnit(
            unitFile, 
            srcDir, 
            cu, 
            p, 
            moduleManager, 
            moduleSourceMapper, 
            typeChecker, 
            tokenStream) {
        
    }

    shared new clone(PhasedUnit other) 
            extends IdePhasedUnit.clone(other) {
    }
    
    shared actual IdeModuleSourceMapperAlias moduleSourceMapper => 
            unsafeCast<IdeModuleSourceMapperAlias>(super.moduleSourceMapper);
    
    shared actual FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> unitFile =>
            unsafeCast<FileVirtualFileAlias>(super.unitFile);

    shared actual FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile> srcDir =>
            unsafeCast<FolderVirtualFileAlias>(super.srcDir);
}

