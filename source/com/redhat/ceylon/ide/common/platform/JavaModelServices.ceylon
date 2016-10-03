import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror
}
import com.redhat.ceylon.model.loader.model {
    LazyPackage
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}
shared interface JavaModelServices<JavaClassRoot> {
    shared formal JavaClassRoot? getJavaClassRoot(ClassMirror classMirror);
    shared formal Unit newCrossProjectJavaCompilationUnit(BaseCeylonProject ceylonProject, JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newCrossProjectBinaryUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newJavaCompilationUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newCeylonBinaryUnit(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
    shared formal Unit newJavaClassFile(JavaClassRoot typeRoot, String relativePath, String fileName, String fullPath, LazyPackage pkg);
}