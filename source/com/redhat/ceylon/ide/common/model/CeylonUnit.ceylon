import java.lang.ref {
    WeakReference
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.typechecker {
    IdePhasedUnit
}

shared abstract class CeylonUnit() extends IdeUnit() {
    
    shared variable default WeakReference<out IdePhasedUnit>? phasedUnitRef = null;
    
    shared PhasedUnitType createPhasedUnitRef<PhasedUnitType>(PhasedUnitType phasedUnit)
        given PhasedUnitType satisfies IdePhasedUnit {
        phasedUnitRef = WeakReference<PhasedUnitType>(phasedUnit);
        return phasedUnit;
    }
    
    shared formal IdePhasedUnit? setPhasedUnitIfNecessary();
    
    shared default IdePhasedUnit? phasedUnit => 
            setPhasedUnitIfNecessary();
    
    shared formal String? ceylonFileName;
    shared formal String? ceylonSourceRelativePath;
    shared formal String? ceylonSourceFullPath;
    
    shared Tree.CompilationUnit? compilationUnit => 
            phasedUnit?.compilationUnit;
    
}
