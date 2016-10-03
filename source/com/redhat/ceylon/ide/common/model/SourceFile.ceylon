import com.redhat.ceylon.ide.common.typechecker {
    IdePhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

shared abstract class SourceFile(IdePhasedUnit phasedUnit)
        extends CeylonUnit(phasedUnit)
        satisfies Source {
    
    language = Language.ceylon;
    
    shared formal Boolean modifiable;
    
    shared actual Package \ipackage => super.\ipackage;
    
    assign \ipackage {
        value p = \ipackage;
        super.\ipackage = \ipackage;
        if (is SingleSourceUnitPackage p,
            !p.unit exists,
            filename.equals(ModuleManager.packageFile)) {
            if (p.fullPathOfSourceUnitToTypecheck==fullPath) {
                p.unit = this;
            }
        }
    }
    
    shared actual String sourceFileName => filename;
    shared actual String sourceRelativePath => relativePath;
    shared actual String sourceFullPath => fullPath;
    shared actual String ceylonSourceRelativePath => relativePath;
    shared actual String ceylonSourceFullPath => sourceFullPath;
    shared actual String ceylonFileName => filename;
}
