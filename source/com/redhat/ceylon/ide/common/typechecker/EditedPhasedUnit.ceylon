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
import com.redhat.ceylon.ide.common.model {
    ModelAliases,
    EditedSourceFile,
    isCentralModelDeclaration
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Declaration
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



shared class EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    WeakReference<ProjectPhasedUnitAlias> savedPhasedUnitRef;
    
    shared new (
            FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile, 
            FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir, 
            Tree.CompilationUnit cu, 
            Package p, 
            ModuleManager moduleManager, 
            ModuleSourceMapper moduleSourceMapper, 
            TypeChecker typeChecker, 
            JList<CommonToken> tokens,
            ProjectPhasedUnitAlias? savedPhasedUnit)
                extends ModifiablePhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile>(
            unitFile,
            srcDir,
            cu,
            p,
            moduleManager,
            moduleSourceMapper,
            typeChecker,
            tokens) {
        
        savedPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(savedPhasedUnit);

        // TODO : do this when instanciating the function
        //if (exists savedPhasedUnit) {
        //    savedPhasedUnit.addWorkingCopy(this);
        //}
    }
    
    shared actual TypecheckerUnit newUnit() {
        return EditedSourceFile(this);
    }
    
    shared actual EditedSourceFileAlias? unit {
        assert(is EditedSourceFileAlias? esf=super.unit);
        return esf;
    }

    shared ProjectPhasedUnitAlias? originalPhasedUnit =>
            savedPhasedUnitRef.get();
    
    shared actual NativeFile? resourceFile =>
            originalPhasedUnit?.resourceFile;
    
    shared actual NativeFolder? resourceRootFolder =>
            originalPhasedUnit?.resourceRootFolder;

    shared actual NativeProject? resourceProject =>
            originalPhasedUnit?.resourceProject;
    
    shared actual Boolean isAllowedToChangeModel(Declaration declaration) =>
            !isCentralModelDeclaration(declaration);
}





