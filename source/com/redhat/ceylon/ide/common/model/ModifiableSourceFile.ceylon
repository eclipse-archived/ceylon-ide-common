import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases,
    ModifiablePhasedUnit
}
shared abstract class ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        (ModifiablePhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> modifiablePhasedUnit)
        extends SourceFile(modifiablePhasedUnit)
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    modifiable => true;
    
    shared actual formal ModifiablePhasedUnitAlias? phasedUnit;

}

shared alias AnyModifiableSourceFile 
        => ModifiableSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;