import com.redhat.ceylon.model.typechecker.model {
    Declaration
}
import com.redhat.ceylon.ide.common.util {
    ProgressMonitor
}
shared interface IJavaModelAware<NativeProject,JavaClassRoot,JavaElement> satisfies IProjectAware<NativeProject> {
    shared formal JavaClassRoot typeRoot;
    shared formal JavaElement toJavaElement(Declaration ceylonDeclaration, ProgressMonitor? monitor = null);
    shared formal NativeProject javaClassRootToNativeProject(JavaClassRoot javaClassRoot);
    shared actual NativeProject? project => 
            javaClassRootToNativeProject(typeRoot);
}