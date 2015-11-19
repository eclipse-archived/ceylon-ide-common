import com.redhat.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import java.util {
    JList=List
}
import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit,
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.ide.common.model {
    ExternalSourceFile
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
    Package
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}

shared class ExternalPhasedUnit 
        extends IdePhasedUnit {
    shared new(ZipEntryVirtualFile unitFile, ZipFileVirtualFile srcDir,
        Tree.CompilationUnit cu, Package p, ModuleManager moduleManager,
        ModuleSourceMapper moduleSourceMapper,
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
    }
    
    shared new clone(PhasedUnit other) 
            extends IdePhasedUnit.clone(other) {
    }
    
    shared actual default TypecheckerUnit newUnit() =>
            ExternalSourceFile(this);
    
    shared actual default ExternalSourceFile unit =>
            unsafeCast<ExternalSourceFile>(super.unit);
    
    shared actual ZipFileVirtualFile srcDir =>
            unsafeCast<ZipFileVirtualFile>(super.srcDir);

    shared actual ZipEntryVirtualFile unitFile => 
            unsafeCast<ZipEntryVirtualFile>(super.unitFile);
}