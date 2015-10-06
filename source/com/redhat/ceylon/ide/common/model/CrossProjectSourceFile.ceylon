import com.redhat.ceylon.ide.common.typechecker {
    CrossProjectPhasedUnit,
    ProjectPhasedUnit
}
shared class CrossProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ExternalSourceFile 
        satisfies ICrossProjectReference<NativeProject, NativeResource, NativeFolder, NativeFile> {
    
    shared new (CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> thePhasedUnit) 
            extends ExternalSourceFile(thePhasedUnit) {
    }
    
    shared actual NativeProject? resourceProject {
        ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? ppu = phasedUnit.originalProjectPhasedUnit;
        return if (exists ppu) then ppu.resourceProject else null;
    }
    
    shared actual NativeFolder? resourceRootFolder {
        ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? ppu = phasedUnit.originalProjectPhasedUnit;
        return if (exists ppu) then ppu.resourceRootFolder else null;
    }
    
    shared actual NativeFile? resourceFile {
        ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? ppu = phasedUnit.originalProjectPhasedUnit;
        return if (exists ppu) then ppu.resourceFile else null;
    }
    
    shared actual CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> phasedUnit {
        assert(is CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> cppu =
            super.phasedUnit);
        return cppu;
    }
    
    shared actual ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>? originalSourceFile => 
            originalPhasedUnit?.unit;
    
    shared actual ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? originalPhasedUnit => 
            phasedUnit.originalProjectPhasedUnit;
    
}
