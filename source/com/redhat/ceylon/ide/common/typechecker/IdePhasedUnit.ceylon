import com.redhat.ceylon.ide.common.vfs {
    BaseFileVirtualFile,
    BaseFolderVirtualFile
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit,
    PhasedUnit
}
import java.lang.ref {
    WeakReference
}
import java.util {
    JList=List
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Unit
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.ide.common.model {
    BaseIdeModuleSourceMapper
}

shared abstract class IdePhasedUnit
        extends PhasedUnit {

    variable WeakReference<TypeChecker>? typeCheckerRef = null;

    shared new(
        BaseFileVirtualFile unitFile,
        BaseFolderVirtualFile srcDir,
        Tree.CompilationUnit cu,
        Package p,
        ModuleManager moduleManager,
        ModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker,
        JList<CommonToken> tokenStream) extends PhasedUnit(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker.context, tokenStream) {
        typeCheckerRef = WeakReference<TypeChecker>(typeChecker);
    }

    shared new clone(PhasedUnit other) extends PhasedUnit(other) {
        if (is IdePhasedUnit other) {
            typeCheckerRef = WeakReference<TypeChecker>(other.typeChecker);
        }
    }

    shared actual default BaseIdeModuleSourceMapper moduleSourceMapper => 
            unsafeCast<BaseIdeModuleSourceMapper>(super.moduleSourceMapper);
    
    shared actual default BaseFileVirtualFile unitFile =>
            unsafeCast<BaseFileVirtualFile>(super.unitFile);

    shared actual default BaseFolderVirtualFile srcDir =>
            unsafeCast<BaseFolderVirtualFile>(super.srcDir);

    shared TypeChecker? typeChecker {
        return typeCheckerRef?.get();
    }

    shared actual default TypecheckerUnit createUnit() {
        Unit? oldUnit = super.unit;
        value theNewUnit = newUnit();
        if (exists oldUnit) {
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