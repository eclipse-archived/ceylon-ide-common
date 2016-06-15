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
    isCentralModelDeclaration,
    BaseIdeModuleSourceMapper
}
import com.redhat.ceylon.ide.common.platform {
    ModelServicesConsumer
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


shared alias AnyEditedPhasedUnit => EditedPhasedUnit<in Nothing, in Nothing, in Nothing, in Nothing>;

shared class EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
            FileVirtualFile<NativeProject,NativeResource, NativeFolder, NativeFile> unitFile, 
            FolderVirtualFile<NativeProject,NativeResource, NativeFolder, NativeFile> srcDir, 
            Tree.CompilationUnit cu, 
            Package p, 
            ModuleManager moduleManager, 
            BaseIdeModuleSourceMapper moduleSourceMapper, 
            TypeChecker typeChecker, 
            JList<CommonToken> tokens,
            ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? savedPhasedUnit,
            NativeProject? project,
            NativeFile file)
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
            unitFile,
            srcDir,
            cu,
            p,
            moduleManager,
            moduleSourceMapper,
            typeChecker,
            tokens)
        satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    value savedPhasedUnitRef = WeakReference(savedPhasedUnit);

        // TODO : do this when instanciating the function
        //if (exists savedPhasedUnit) {
        //    savedPhasedUnit.addWorkingCopy(this);
        //}
    shared actual TypecheckerUnit createUnit() 
            => object satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>{
            }.modelServices.newEditedSourceFile(this);
    
    /*shared actual EditedSourceFileAlias? unit =>
            unsafeCast<EditedSourceFileAlias?>(super.unit);*/

    shared ProjectPhasedUnitAlias? originalPhasedUnit 
            => savedPhasedUnitRef.get();
    
    shared actual NativeProject? resourceProject => project;
    shared actual NativeFile resourceFile => file;
    
    resourceRootFolder => originalPhasedUnit?.resourceRootFolder;
    
    isAllowedToChangeModel(Declaration declaration) 
            => !isCentralModelDeclaration(declaration);
}





