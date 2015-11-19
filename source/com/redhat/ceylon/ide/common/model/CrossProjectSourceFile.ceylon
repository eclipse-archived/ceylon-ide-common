import com.redhat.ceylon.ide.common.typechecker {
    CrossProjectPhasedUnit,
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
shared class CrossProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ExternalSourceFile 
        satisfies ICrossProjectReference<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    
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
    
    shared actual CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> phasedUnit =>
            unsafeCast<CrossProjectPhasedUnitAlias>(super.phasedUnit);
    
    shared actual ProjectSourceFileAlias? originalSourceFile => 
            originalPhasedUnit?.unit;
    
    shared actual ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? originalPhasedUnit => 
            phasedUnit.originalProjectPhasedUnit;
    
}
