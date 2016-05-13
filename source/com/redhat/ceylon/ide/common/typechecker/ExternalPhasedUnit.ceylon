import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    ExternalSourceFile,
    BaseIdeModuleSourceMapper,
    CeylonUnit
}
import com.redhat.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile
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

shared class ExternalPhasedUnit extends IdePhasedUnit {
    
    ZipEntryVirtualFile _unitFile;
    ZipFileVirtualFile _srcDir;
    
    shared new (ZipEntryVirtualFile unitFile, ZipFileVirtualFile srcDir,
        Tree.CompilationUnit cu, Package p, ModuleManager moduleManager,
        BaseIdeModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker, JList<CommonToken> tokenStream) 
            extends IdePhasedUnit(
            unitFile, 
            srcDir, 
            cu, 
            p, 
            moduleManager, 
            moduleSourceMapper, 
            typeChecker, 
            tokenStream) {
        this._unitFile = unitFile;
        this._srcDir = srcDir;
    }
    
    shared new clone(ExternalPhasedUnit other) 
            extends IdePhasedUnit.clone(other) {
        this._srcDir = other.srcDir;
        this._unitFile = other.unitFile;
    }
    
    shared actual default TypecheckerUnit newUnit() 
            => ExternalSourceFile(this);
    
    shared actual CeylonUnit unit {
        assert (is CeylonUnit unit = super.unit);
        return unit;
    }
    
    shared actual ZipFileVirtualFile srcDir => _srcDir;
    shared actual ZipEntryVirtualFile unitFile => _unitFile;
    
}