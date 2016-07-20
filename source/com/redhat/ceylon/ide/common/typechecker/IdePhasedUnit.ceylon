import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.model {
    BaseIdeModuleSourceMapper
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils
}
import com.redhat.ceylon.ide.common.vfs {
    BaseFileVirtualFile,
    BaseFolderVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.lang.ref {
    WeakReference
}
import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class IdePhasedUnit
        extends PhasedUnit {

    WeakReference<TypeChecker> typeCheckerRef;

    BaseFileVirtualFile _unitFile;
    BaseFolderVirtualFile _srcDir;
    
    shared new(
        BaseFileVirtualFile unitFile,
        BaseFolderVirtualFile srcDir,
        Tree.CompilationUnit cu,
        Package p,
        ModuleManager moduleManager,
        BaseIdeModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker,
        JList<CommonToken> tokenStream) 
            extends PhasedUnit(unitFile, srcDir, cu, p, 
                moduleManager, moduleSourceMapper, 
                typeChecker.context, tokenStream) {
        typeCheckerRef = WeakReference(typeChecker);
        this._unitFile = unitFile; 
        this._srcDir = srcDir;
    }

    shared new clone(IdePhasedUnit other) 
            extends PhasedUnit(other) {
        typeCheckerRef = WeakReference(other.typeChecker);
        this._unitFile = other.unitFile; 
        this._srcDir = other.srcDir;
    }
    
    shared TypeChecker? typeChecker => typeCheckerRef.get();
    
    shared actual BaseIdeModuleSourceMapper? moduleSourceMapper {
        assert (is BaseIdeModuleSourceMapper? mapper 
                    = super.moduleSourceMapper);
        return mapper;
    }
    
    shared actual default BaseFileVirtualFile unitFile => _unitFile;
    shared actual default BaseFolderVirtualFile srcDir => _srcDir;
    
    shared actual Boolean handleException(Exception e, Node that) {
        if (platformUtils.isOperationCanceledException(e) ||
        platformUtils.isExceptionToPropagateInVisitors(e)) {
            throw e;
        }
        return false;
    }
}