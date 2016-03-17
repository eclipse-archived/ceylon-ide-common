import com.redhat.ceylon.ide.common.model {
    ModelAliases,
    ProjectSourceFile,
    EditedSourceFile,
    CrossProjectSourceFile
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases,
    CrossProjectPhasedUnit,
    EditedPhasedUnit,
    ProjectPhasedUnit
}

shared interface ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    "Instanciate a [[ProjectSourceFile]] object from a [[ProjectPhasedUnit]] 
     with the concrete type parameters corresponding to the current IDE platform
    
     Necessary because of [issue #25](https://github.com/ceylon/ceylon-ide-common/issues/25)"
    shared formal ProjectSourceFileAlias newProjectSourceFile(ProjectPhasedUnitAlias phasedUnit);
    
    "Instanciate a [[CrossProjectSourceFile]] object from a [[CrossProjectPhasedUnit]] 
     with the concrete type parameters corresponding to the current IDE platform
    
     Necessary because of [issue #25](https://github.com/ceylon/ceylon-ide-common/issues/25)"
    shared formal CrossProjectSourceFileAlias newCrossProjectSourceFile(CrossProjectPhasedUnitAlias phasedUnit);
    
    "Instanciate a [[EditedSourceFile]] object from an [[EditedPhasedUnit]] 
     with the concrete type parameters corresponding to the current IDE platform
     
     Necessary because of [issue #25](https://github.com/ceylon/ceylon-ide-common/issues/25)"
    shared formal EditedSourceFileAlias newEditedSourceFile(EditedPhasedUnitAlias phasedUnit);
}