import java.lang.ref {
    WeakReference
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.typechecker {
    IdePhasedUnit
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}

shared abstract class CeylonUnit extends IdeUnit {
    
    variable WeakReference<out IdePhasedUnit> phasedUnitRef;
    
    shared new (IdePhasedUnit phasedUnit) 
            extends IdeUnit(phasedUnit.moduleSourceMapper) {
        phasedUnitRef = WeakReference(phasedUnit);
    }
    
    shared new init(String theFilename, 
                    String theRelativePath, 
                    String theFullPath, 
                    Package thePackage) 
            extends IdeUnit.init(theFilename, 
                                theRelativePath, 
                                theFullPath, 
                                thePackage) {
        phasedUnitRef = WeakReference<IdePhasedUnit>(null);
    }
    
    shared default IdePhasedUnit? findPhasedUnit() => null;
    
    shared default IdePhasedUnit? phasedUnit {
        value result 
                = phasedUnitRef.get() 
                else findPhasedUnit();
        phasedUnitRef = WeakReference(result);
        return result;
    }
    
    shared formal String? ceylonFileName;
    shared formal String? ceylonSourceRelativePath;
    shared formal String? ceylonSourceFullPath;
    
    shared Tree.CompilationUnit? compilationUnit 
            => phasedUnit?.compilationUnit;
    
}
