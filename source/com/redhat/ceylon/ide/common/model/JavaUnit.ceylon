import com.redhat.ceylon.ide.common.model {
    BaseIdeModule,
    IResourceAware,
    IdeUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared interface JavaUnitUtils<NativeFolder,NativeFile,JavaClassRoot> {
    shared formal NativeFile? javaClassRootToNativeFile(JavaClassRoot javaClassRoot);
    shared formal NativeFolder? javaClassRootToNativeRootFolder(JavaClassRoot javaClassRoot);
}

shared abstract class JavaUnit<NativeProject,NativeFolder,NativeFile,JavaClassRoot,JavaElement>(
            filename, 
            relativePath, 
            fullPath, 
            \ipackage)
        extends IdeUnit()
        satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement> 
        & IResourceAware<NativeProject, NativeFolder, NativeFile>
        & JavaUnitUtils<NativeFolder, NativeFile, JavaClassRoot> {
    
    shared actual variable String filename;
    shared actual variable String relativePath;
    shared actual variable String fullPath;
    shared actual variable Package \ipackage;
    
    shared actual NativeFile? resourceFile =>
            javaClassRootToNativeFile(typeRoot);
    
    shared actual NativeProject? resourceProject =>
            project;
    
    shared actual NativeFolder? resourceRootFolder {
        if (exists rf=resourceFile) {
            return javaClassRootToNativeRootFolder(typeRoot);
        }
        
        return null;
    }
    
    shared void remove() {
        value p = \ipackage;
        p.removeUnit(this);
        assert (is BaseIdeModule m = p.\imodule);
        m.moduleInReferencingProjects
            .each((BaseIdeModule m) 
                => m.removedOriginalUnit(relativePath));
    }
}
