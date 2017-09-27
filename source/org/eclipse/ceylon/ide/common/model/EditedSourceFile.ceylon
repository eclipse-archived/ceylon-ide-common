import org.eclipse.ceylon.ide.common.typechecker {
    EditedPhasedUnit,
    TypecheckerAliases
}
import java.lang.ref {
    WeakReference
}

shared class EditedSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        (EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> editedPhasedUnit)
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
                (editedPhasedUnit)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    value editedPhasedUnitRef = WeakReference(editedPhasedUnit);
    
    shared actual EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? phasedUnit
            => editedPhasedUnitRef.get();
    
    shared ProjectSourceFileAlias? originalSourceFile 
            => phasedUnit?.originalPhasedUnit?.unit;
    
    resourceProject => phasedUnit?.resourceProject;
    resourceFile => phasedUnit?.resourceFile;
    resourceRootFolder => phasedUnit?.resourceRootFolder;
    
}

