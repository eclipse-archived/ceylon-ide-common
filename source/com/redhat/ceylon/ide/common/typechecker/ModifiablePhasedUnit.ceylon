import java.util {
    List
}
import org.antlr.runtime {
    CommonToken
}
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
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.ide.common.model {
    IResourceAware
}
import com.redhat.ceylon.ide.common.vfs {
    FileVirtualFile,
    FolderVirtualFile
}

shared abstract class ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends IdePhasedUnit
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    shared new (
        FileVirtualFile<NativeResource,NativeFolder,NativeFile> unitFile, 
        FolderVirtualFile<NativeResource,NativeFolder,NativeFile> srcDir, 
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
    
    shared actual FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile {
        assert(is FileVirtualFile<NativeResource, NativeFolder, NativeFile> uf=super.unitFile);
        return uf;
    }

    shared actual FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir {
        assert(is FolderVirtualFile<NativeResource, NativeFolder, NativeFile> sd=super.srcDir);
        return sd;
    }
}

