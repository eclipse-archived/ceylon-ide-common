import com.redhat.ceylon.ide.common.typechecker {
    EditedPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}

shared class EditedSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared new (EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> phasedUnit)
            extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(phasedUnit) {
    }

    shared actual EditedPhasedUnitAlias? phasedUnit =>
            unsafeCast<EditedPhasedUnitAlias?>(super.phasedUnit);
    
    shared ProjectSourceFileAlias? originalSourceFile =>
            phasedUnit?.originalPhasedUnit?.unit;
    
    shared actual NativeProject? resourceProject =>
            phasedUnit?.resourceProject;
    
    shared actual NativeFile? resourceFile =>
            phasedUnit?.resourceFile;
    
    shared actual NativeFolder? resourceRootFolder =>
            phasedUnit?.resourceRootFolder;
    
}

