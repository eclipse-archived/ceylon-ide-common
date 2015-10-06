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
shared class CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> 
        extends ExternalPhasedUnit {
    
    variable value originalProjectRef = WeakReference<CeylonProject<NativeProject>>(null);
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
        CeylonProject<NativeProject> originalProject) 
            extends ExternalPhasedUnit(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker, tokenStream) {
        originalProjectRef = WeakReference<CeylonProject<NativeProject>>(originalProject);
    }
    
    shared new clone(CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> other)
            extends ExternalPhasedUnit.clone(other) {
        originalProjectRef = WeakReference<CeylonProject<NativeProject>>(other.originalProjectRef.get());
        originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>>(other.originalProjectPhasedUnit);
    }
    
    shared ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>? originalProjectPhasedUnit {
        if (exists originalPhasedUnit = originalProjectPhasedUnitRef.get()) {
            return originalPhasedUnit;
        } 
        CeylonProject<NativeProject>? originalProject = originalProjectRef.get();
        if (exists originalProject) {
            TypeChecker? originalTypeChecker = originalProject.typechecker;
            if (exists originalTypeChecker,
                is ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> originalPhasedUnit =
                        originalTypeChecker.getPhasedUnitFromRelativePath(pathRelativeToSrcDir)) {
                originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>>(originalPhasedUnit);
                return originalPhasedUnit;
            }
        }
        
        return null;
    }
    
    shared actual TypecheckerUnit newUnit() {
        return CrossProjectSourceFile(this);
    }
    
    shared actual CrossProjectSourceFile<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> unit {
        assert(is CrossProjectSourceFile<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> cpsf = super.unit);
        return cpsf;
    }
}
