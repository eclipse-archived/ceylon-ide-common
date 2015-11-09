import com.redhat.ceylon.ide.common.model {
    BaseIdeModule,
    IResourceAware,
    IdeUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class JavaUnit<NativeProject,NativeFolder,NativeFile,JavaClassRoot,JavaElement>(
            filename, 
            relativePath, 
            fullPath, 
            \ipackage)
        extends IdeUnit()
        satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement> 
        & IResourceAware<NativeProject, NativeFolder, NativeFile> {
    
    shared actual variable String filename;
    shared actual variable String relativePath;
    shared actual variable String fullPath;
    shared actual variable Package \ipackage;
    
    shared formal NativeFile? javaClassRootToNativeFile(JavaClassRoot javaClassRoot);
    shared formal NativeFolder? javaClassRootToNativeRootFolder(JavaClassRoot javaClassRoot);

    shared actual NativeFile? resourceFile =>
            javaClassRootToNativeFile(typeRoot);
    
    shared actual NativeProject? resourceProject =>
            project;
    
    shared actual NativeFolder? resourceRootFolder {
        if (exists rf=resourceFile) {
            return javaClassRootToNativeRootFolder(typeRoot);
            //try {
            //    assert (is IPackageFragmentRoot root = typeRoot.getAncestor(IJavaElement.\iPACKAGE_FRAGMENT_ROOT));
            //    if (exists root) {
            //        return root.correspondingResource;
            //    }
            //} catch (JavaModelException e) {
            //    e.printStackTrace();
            //}
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
