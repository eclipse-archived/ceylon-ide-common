import java.lang.ref {
    WeakReference
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.ide.common.typechecker {
    CrossProjectPhasedUnit,
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class CrossProjectBinaryUnit<NativeProject,NativeResource,NativeFolder,NativeFile,JavaClassFile,JavaClassRoot,JavaElement>
        extends CeylonBinaryUnit<NativeProject,JavaClassFile,JavaClassRoot,JavaElement> 
        satisfies ICrossProjectReference<NativeProject,NativeResource,NativeFolder,NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource
        given JavaClassFile satisfies JavaClassRoot {
    
    variable value originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(null);
    
    shared new (JavaClassFile typeRoot, String fileName, String relativePath, String fullPath, Package pkg) 
            extends CeylonBinaryUnit<NativeProject, JavaClassFile, JavaClassRoot, JavaElement>(
                typeRoot,
                fileName,
                relativePath,
                fullPath,
                pkg) {
    }
    
    shared actual NativeProject? resourceProject =>
            phasedUnit?.originalProjectPhasedUnit?.resourceProject;
    
    shared actual NativeFolder? resourceRootFolder =>
            phasedUnit?.originalProjectPhasedUnit?.resourceRootFolder;
    
    shared actual NativeFile? resourceFile =>
            phasedUnit?.originalProjectPhasedUnit?.resourceFile;
    
    shared actual CrossProjectPhasedUnitAlias? phasedUnit {
        assert(is CrossProjectPhasedUnitAlias? cppu=super.phasedUnit);
        return cppu;
    }
    
    shared actual ProjectSourceFileAlias? originalSourceFile =>
            originalPhasedUnit?.unit;
    
    shared actual ProjectPhasedUnitAlias? originalPhasedUnit {
        variable ProjectPhasedUnitAlias? original = originalProjectPhasedUnitRef.get();
        if (! original exists) {
            value theModule = ceylonModule;
            value originalProject = theModule.originalProject;
            if (exists originalProject,
                exists originalTypeChecker = originalProject.typechecker,
                exists pu = 
                    originalTypeChecker.getPhasedUnitFromRelativePath(
                        theModule.toSourceUnitRelativePath(relativePath))) {
                assert(is ProjectPhasedUnitAlias pu);
                original = pu;
                originalProjectPhasedUnitRef = WeakReference<ProjectPhasedUnitAlias>(original);
            }
        }
        
        return original;
    }
}
