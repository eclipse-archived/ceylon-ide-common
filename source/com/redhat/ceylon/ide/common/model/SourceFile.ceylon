import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.ide.common.typechecker {
    IdePhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage
}
import java.lang.ref {
    WeakReference
}

shared abstract class SourceFile(
    IdePhasedUnit phasedUnit) 
        extends CeylonUnit() {
    
    shared variable actual WeakReference<out IdePhasedUnit>? phasedUnitRef = 
            WeakReference<IdePhasedUnit>(phasedUnit);

    shared actual Package \ipackage {
        return super.\ipackage;
    }
    assign \ipackage {
        value p = \ipackage;
        super.\ipackage = \ipackage;
        if (is SingleSourceUnitPackage p,
            ! p.unit exists,
            filename.equals(ModuleManager.\iPACKAGE_FILE)) {
            if (p.fullPathOfSourceUnitToTypecheck.equals(fullPath)) {
                p.unit = this;
            }
        }
    }

    shared actual IdePhasedUnit? setPhasedUnitIfNecessary() =>
            phasedUnitRef?.get();
    
    shared actual String sourceFileName => 
            filename;
    
    shared actual String sourceRelativePath => 
            relativePath;
    
    shared actual String sourceFullPath => 
            fullPath;
    
    shared actual String ceylonSourceRelativePath => 
            relativePath;
    
    shared actual String ceylonSourceFullPath => 
            sourceFullPath;
    
    shared actual String ceylonFileName => 
            filename;
}
