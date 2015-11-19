import java.lang.ref {
    WeakReference
}
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
    TypecheckerUnit
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
    CeylonProject,
    CrossProjectSourceFile
}
import com.redhat.ceylon.ide.common.vfs {
    ZipEntryVirtualFile,
    ZipFileVirtualFile
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
shared class CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> 
        extends ExternalPhasedUnit
        given NativeProject satisfies Object
        given OriginalNativeResource satisfies Object
        given OriginalNativeFolder satisfies OriginalNativeResource
        given OriginalNativeFile satisfies OriginalNativeResource {
    
    shared alias CeylonProjectAlias => CeylonProject<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>;
    shared alias ProjectPhasedUnitAlias => ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>;
    shared alias CrossProjectPhasedUnitAlias => CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>;
    shared alias CrossProjectSourceFileAlias => CrossProjectSourceFile<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>;
    
    variable value originalProjectRef = WeakReference<CeylonProjectAlias>(null);
    variable value originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>>(null);
    
    shared new (
        ZipEntryVirtualFile unitFile, 
        ZipFileVirtualFile srcDir, 
        Tree.CompilationUnit cu, 
        Package p, 
        ModuleManager moduleManager, 
        ModuleSourceMapper moduleSourceMapper, 
        TypeChecker typeChecker, 
        List<CommonToken> tokenStream, 
        CeylonProjectAlias originalProject) 
            extends ExternalPhasedUnit(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker, tokenStream) {
        originalProjectRef = WeakReference<CeylonProjectAlias>(originalProject);
    }
    
    shared new clone(CrossProjectPhasedUnitAlias other)
            extends ExternalPhasedUnit.clone(other) {
        originalProjectRef = WeakReference<CeylonProjectAlias>(other.originalProjectRef.get());
        originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(other.originalProjectPhasedUnit);
    }
    
    shared ProjectPhasedUnitAlias? originalProjectPhasedUnit {
        if (exists originalPhasedUnit = originalProjectPhasedUnitRef.get()) {
            return originalPhasedUnit;
        } 
        CeylonProjectAlias? originalProject = originalProjectRef.get();
        if (exists originalProject) {
            TypeChecker? originalTypeChecker = originalProject.typechecker;
            if (exists originalTypeChecker,
                is ProjectPhasedUnitAlias originalPhasedUnit =
                        originalTypeChecker.getPhasedUnitFromRelativePath(pathRelativeToSrcDir)) {
                originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(originalPhasedUnit);
                return originalPhasedUnit;
            }
        }
        
        return null;
    }
    
    shared actual TypecheckerUnit newUnit() =>
            CrossProjectSourceFile(this);
    
    shared actual CrossProjectSourceFileAlias unit =>
            unsafeCast<CrossProjectSourceFileAlias>(super.unit);
}
