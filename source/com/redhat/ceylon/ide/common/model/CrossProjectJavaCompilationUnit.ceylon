import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.model.typechecker.model {
    Unit
}
import com.redhat.ceylon.model.loader.model {
    LazyPackage
}
import java.lang.ref {
    WeakReference
}
import com.redhat.ceylon.ide.common.platform {
    JavaModelServicesConsumer
}

shared abstract class CrossProjectJavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
            BaseCeylonProject originalProject,
            JavaClassRoot typeRoot, 
            String filename,
            String relativePath,
            String fullPath,
            LazyPackage pkg)
        extends JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(typeRoot, filename, relativePath, fullPath, pkg)
        satisfies ICrossProjectReference<NativeProject, NativeFolder, NativeFile>
        & JavaModelServicesConsumer<JavaClassRoot> {
    
    function findOriginalSourceFile() => 
            let(searchedPackageName = pkg.nameAsString)
    if (exists members=originalProject.modules?.fromProject?.flatMap((m) => CeylonIterable(m.packages))
        ?.find((p) => p.nameAsString == searchedPackageName)
            ?.members)
    then CeylonIterable(members).map((decl) => decl.unit)
            .narrow<JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>>()
            .find((unit) => unit.fullPath == fullPath)
    else null;

    variable value originalUnitReference = WeakReference(findOriginalSourceFile());

    shared actual Unit clone() 
            => javaModelServices.newCrossProjectJavaCompilationUnit(originalProject, typeRoot, relativePath, filename, fullPath, pkg);
    
    shared actual JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>? originalSourceFile {
        if (exists original = 
                originalUnitReference.get()) {
            return original;
        }
        else {
            if (exists theOriginalUnit = findOriginalSourceFile()) {
                originalUnitReference = WeakReference(theOriginalUnit);
                return theOriginalUnit;
            }
        }
        return null;
    }
}
