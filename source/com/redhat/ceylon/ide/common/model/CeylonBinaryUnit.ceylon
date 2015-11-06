import com.redhat.ceylon.ide.common.model {
    CeylonUnit
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit,
    IdePhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class CeylonBinaryUnit<NativeProject, JavaClassFile, JavaClassRoot, JavaElement>(typeRoot, filename, relativePath, fullPath, \ipackage)
        extends CeylonUnit() satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement> 
        given JavaClassFile satisfies JavaClassRoot {
    shared variable actual String filename;
    shared variable actual String relativePath;
    shared variable actual String fullPath;
    shared variable actual Package \ipackage;
    shared actual JavaClassFile typeRoot;
    
    shared actual default ExternalPhasedUnit? phasedUnit {
        assert(is ExternalPhasedUnit? epu=super.phasedUnit);
        return epu;
    }
    
    shared actual ExternalPhasedUnit? setPhasedUnitIfNecessary() {
        variable IdePhasedUnit? phasedUnit = null;
        if (exists ref=phasedUnitRef) {
            phasedUnit = ref.get();
        }
        
        if (! phasedUnit exists) {
            try {
                if (exists artifact = ceylonModule.artifact) {
                    value binaryUnitRelativePath = fullPath.replace(artifact.path + "!/", "");
                    value sourceUnitRelativePath = ceylonModule.toSourceUnitRelativePath(binaryUnitRelativePath);
                    if (exists sourceUnitRelativePath) {
                        phasedUnit = ceylonModule.getPhasedUnitFromRelativePath(sourceUnitRelativePath);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        return if (is ExternalPhasedUnit pu=phasedUnit) 
        then createPhasedUnitRef(pu) 
        else null;
    }
    
    String? computeFullPath(String? relativePath) =>
            if (exists archivePath = ceylonModule.sourceArchivePath,
                exists relativePath)
            then "``archivePath``!/``relativePath``"
            else null;
    
    shared actual String? sourceFileName =>
            sourceRelativePath?.split('/'.equals)?.last;
    
    shared actual String? sourceRelativePath =>
            ceylonModule.toSourceUnitRelativePath(relativePath);
    
    shared actual String? sourceFullPath => 
            computeFullPath(sourceRelativePath);
    
    shared actual String? ceylonSourceRelativePath =>
            ceylonModule.getCeylonDeclarationFile(sourceRelativePath);
    
    shared actual String? ceylonSourceFullPath =>
        computeFullPath(ceylonSourceRelativePath);
    
    shared actual String? ceylonFileName =>
            if (exists crp=ceylonSourceRelativePath,
                    !crp.empty)
            then crp.split('/'.equals).last
            else null;
}
