import com.redhat.ceylon.ide.common.typechecker {
    IdePhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
shared abstract class ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        extends SourceFile 
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    modifiable => true;
    
    shared new (IdePhasedUnit phasedUnit) 
            extends SourceFile(phasedUnit) {
    }
    
    shared actual default ModifiablePhasedUnitAlias? phasedUnit =>
            unsafeCast<ModifiablePhasedUnitAlias?>(super.phasedUnit);

}

shared alias AnyModifiableSourceFile 
        => ModifiableSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;