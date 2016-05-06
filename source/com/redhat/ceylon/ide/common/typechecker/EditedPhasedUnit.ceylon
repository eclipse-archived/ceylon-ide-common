import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    ModelAliases,
    isCentralModelDeclaration
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Declaration,
    Unit
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
import com.redhat.ceylon.ide.common.platform {
    ModelServicesConsumer
}


shared alias AnyEditedPhasedUnit => EditedPhasedUnit<in Nothing, in Nothing, in Nothing, in Nothing>;

shared class EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    WeakReference<ProjectPhasedUnitAlias> savedPhasedUnitRef;
    
    shared new (
            FileVirtualFile<NativeProject,NativeResource, NativeFolder, NativeFile> unitFile, 
            FolderVirtualFile<NativeProject,NativeResource, NativeFolder, NativeFile> srcDir, 
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
    
    shared actual Unit newUnit() => 
            object satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>{
            }.modelServices.newEditedSourceFile(this);
    
    shared actual EditedSourceFileAlias? unit =>
            unsafeCast<EditedSourceFileAlias?>(super.unit);

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





