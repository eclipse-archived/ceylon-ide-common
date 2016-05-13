import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

import java.lang.ref {
    WeakReference
}

shared abstract class CrossProjectBinaryUnit<NativeProject,NativeResource,NativeFolder,NativeFile,JavaClassRoot,JavaElement>
        (JavaClassRoot typeRoot, String fileName, String relativePath, String fullPath, Package thePackage) 
        extends CeylonBinaryUnit<NativeProject,JavaClassRoot,JavaElement>
                (typeRoot, fileName, relativePath, fullPath, thePackage)
        satisfies ICrossProjectReference<NativeProject,NativeResource,NativeFolder,NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    variable value originalProjectPhasedUnitRef 
            = WeakReference<ProjectPhasedUnitAlias>(null);
    
    //TODO: Get rid of this unsafeCast()!
    shared actual CrossProjectPhasedUnitAlias? phasedUnit 
            => unsafeCast<CrossProjectPhasedUnitAlias?>
                    (super.phasedUnit);
    
    originalSourceFile => originalPhasedUnit?.unit;
    
    resourceProject 
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceProject;
    resourceRootFolder 
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceRootFolder;
    
    resourceFile
            => phasedUnit?.originalProjectPhasedUnit
                         ?.resourceFile;
    
    shared actual ProjectPhasedUnitAlias? originalPhasedUnit {
        if (exists original 
                = originalProjectPhasedUnitRef.get()) {
            return original;
        }
        else {
            if (exists originalProject = ceylonModule.originalProject,
                exists originalTypeChecker = originalProject.typechecker,
                exists phasedUnit = 
                    originalTypeChecker.getPhasedUnitFromRelativePath(
                        ceylonModule.toSourceUnitRelativePath(relativePath))) {
                assert (is ProjectPhasedUnitAlias phasedUnit);
                originalProjectPhasedUnitRef = WeakReference(phasedUnit);
                return phasedUnit;
            }
        }
        return null;
    }
}
