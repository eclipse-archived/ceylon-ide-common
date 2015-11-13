import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}
shared interface IJavaModelAware<NativeProject,JavaClassRoot,JavaElement> satisfies IProjectAware<NativeProject> {
    shared formal JavaClassRoot typeRoot;
    shared formal JavaElement? toJavaElement(Declaration ceylonDeclaration, BaseProgressMonitor? monitor = null);
    shared formal NativeProject javaClassRootToNativeProject(JavaClassRoot javaClassRoot);
    shared actual NativeProject? project => 
            javaClassRootToNativeProject(typeRoot);
}