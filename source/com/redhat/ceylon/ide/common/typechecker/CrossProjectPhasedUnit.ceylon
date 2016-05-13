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
    ModelAliases,
    BaseIdeModuleSourceMapper
}
import com.redhat.ceylon.ide.common.platform {
    ModelServicesConsumer
}
import com.redhat.ceylon.ide.common.vfs {
    ZipEntryVirtualFile,
    ZipFileVirtualFile
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
    List
}

import org.antlr.runtime {
    CommonToken
}

shared class CrossProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile> 
        extends ExternalPhasedUnit
        satisfies ModelServicesConsumer<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
                & ModelAliases<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
                & TypecheckerAliases<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>
        given NativeProject satisfies Object
        given OriginalNativeResource satisfies Object
        given OriginalNativeFolder satisfies OriginalNativeResource
        given OriginalNativeFile satisfies OriginalNativeResource {
    
    variable value originalProjectRef = WeakReference<CeylonProjectAlias>(null);
    variable value originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnit<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>>(null);
    
    shared new (
        ZipEntryVirtualFile unitFile, 
        ZipFileVirtualFile srcDir, 
        Tree.CompilationUnit cu, 
        Package p, 
        ModuleManager moduleManager, 
        BaseIdeModuleSourceMapper moduleSourceMapper, 
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
        if (exists originalProject = originalProjectRef.get(), 
            exists originalTypeChecker = originalProject.typechecker,
            is ProjectPhasedUnitAlias originalPhasedUnit =
                    originalTypeChecker.getPhasedUnitFromRelativePath(pathRelativeToSrcDir)) {
            originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(originalPhasedUnit);
            return originalPhasedUnit;
        }
        
        return null;
    }
    
    /*shared actual IdeModuleSourceMapperAlias moduleSourceMapper 
            => unsafeCast<IdeModuleSourceMapperAlias>(super.moduleSourceMapper);*/
    
    shared actual TypecheckerUnit newUnit()
            => object satisfies ModelServicesConsumer<NativeProject, OriginalNativeResource, OriginalNativeFolder, OriginalNativeFile>{
            }.modelServices.newCrossProjectSourceFile(this);
    
    /*shared actual CrossProjectSourceFileAlias unit 
            => unsafeCast<CrossProjectSourceFileAlias>(super.unit);*/
}
