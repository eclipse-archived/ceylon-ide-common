import com.redhat.ceylon.ide.common.model {
    CeylonUnit
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class CeylonBinaryUnit<NativeProject, JavaClassRoot, JavaElement>
        (shared actual JavaClassRoot typeRoot, 
        String theFilename, String theRelativePath, String theFullPath, 
        Package thePackage)
        extends CeylonUnit.init(theFilename, theRelativePath, theFullPath, thePackage)
        satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement>
                & BinaryWithSources {
    
    shared actual default ExternalPhasedUnit? phasedUnit {
        assert (is ExternalPhasedUnit? phasedUnit = super.phasedUnit);
        return phasedUnit;
    }
    
    shared actual ExternalPhasedUnit? findPhasedUnit() {
        try {
            if (exists artifact = ceylonModule.artifact) {
                value binaryUnitRelativePath 
                        = fullPath.replace(artifact.path + "!/", "");
                value sourceUnitRelativePath 
                        = ceylonModule.toSourceUnitRelativePath(
                                binaryUnitRelativePath);
                if (exists sourceUnitRelativePath) {
                    return ceylonModule.getPhasedUnitFromRelativePath(
                                sourceUnitRelativePath);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }
    
    ceylonSourceRelativePath 
            => ceylonModule.getCeylonDeclarationFile(
                    sourceRelativePath);
    ceylonSourceFullPath 
            => computeFullPath(ceylonSourceRelativePath);
    ceylonFileName 
            => if (exists crp = ceylonSourceRelativePath,
                    !crp.empty)
            then crp.split('/'.equals).last
            else null;
    
    binaryRelativePath => relativePath;
    
    sourceFileName 
            => (super of BinaryWithSources)
                .sourceFileName;
    sourceFullPath 
            => (super of BinaryWithSources)
                .sourceFullPath;
    sourceRelativePath 
            => (super of BinaryWithSources)
                .sourceRelativePath;
}
