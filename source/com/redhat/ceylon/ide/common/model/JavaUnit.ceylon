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

shared abstract class BaseJavaUnit<NativeProject,NativeFolder,NativeFile>
        extends IdeUnit
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile> {
    shared new(String theFilename, String theRelativePath, String theFullPath, Package thePackage)
            extends IdeUnit.init(theFilename, theRelativePath, theFullPath, thePackage) {}
    
    shared void remove() {
        value p = \ipackage;
        p.removeUnit(this);
        assert (is BaseIdeModule m = p.\imodule);
        m.moduleInReferencingProjects
                .each((BaseIdeModule m) 
            => m.removedOriginalUnit(relativePath));
    }
}

shared abstract class JavaUnit<NativeProject,NativeFolder,NativeFile,JavaClassRoot,JavaElement>(
    String theFilename, 
    String theRelativePath, 
    String theFullPath, 
    Package thePackage)
        extends BaseJavaUnit<NativeProject,NativeFolder,NativeFile>(theFilename, theRelativePath, theFullPath, thePackage)
        satisfies IJavaModelAware<NativeProject, JavaClassRoot, JavaElement>
        & JavaUnitUtils<NativeFolder, NativeFile, JavaClassRoot> {
    
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
}
