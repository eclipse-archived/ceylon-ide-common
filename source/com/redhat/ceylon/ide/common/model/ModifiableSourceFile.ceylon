import com.redhat.ceylon.ide.common.typechecker {
    IdePhasedUnit,
    ModifiablePhasedUnit
}
shared abstract class ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> 
        extends SourceFile 
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile>
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
    shared new (IdePhasedUnit phasedUnit) 
            extends SourceFile(phasedUnit) {
    }
    
    shared actual ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? phasedUnit {
        assert(is ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? mpu = 
            super.phasedUnit);
        return mpu;
    }
}
