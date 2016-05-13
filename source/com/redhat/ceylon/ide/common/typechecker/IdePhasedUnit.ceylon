import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    TypecheckerUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    BaseIdeModuleSourceMapper
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
    WeakReference<BaseIdeModuleSourceMapper> sourceMapperRef;

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
        sourceMapperRef = WeakReference(moduleSourceMapper);
        this._unitFile = unitFile; 
        this._srcDir = srcDir;
    }

    shared new clone(IdePhasedUnit other) extends PhasedUnit(other) {
        typeCheckerRef = WeakReference(other.typeChecker);
        sourceMapperRef = WeakReference(other.moduleSourceMapper);
        this._unitFile = other.unitFile; 
        this._srcDir = other.srcDir;
    }
    
    shared TypeChecker? typeChecker => typeCheckerRef.get();
    
    shared actual BaseIdeModuleSourceMapper? moduleSourceMapper 
            => sourceMapperRef.get();
    
    shared actual default BaseFileVirtualFile unitFile => _unitFile;
    shared actual default BaseFolderVirtualFile srcDir => _srcDir;
    
    shared actual default TypecheckerUnit createUnit() {
        value theNewUnit = newUnit();
        if (exists oldUnit = super.unit) {
            theNewUnit.filename = oldUnit.filename;
            theNewUnit.fullPath = oldUnit.fullPath;
            theNewUnit.relativePath = oldUnit.relativePath;
            theNewUnit.\ipackage = oldUnit.\ipackage;
            theNewUnit.dependentsOf.addAll(oldUnit.dependentsOf);
        }
        return theNewUnit;
    }

    shared formal TypecheckerUnit newUnit();
}