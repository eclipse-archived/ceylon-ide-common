import com.redhat.ceylon.ide.common.platform {
    JavaModelServicesConsumer
}
import com.redhat.ceylon.model.loader.model {
    LazyPackage
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

shared abstract class JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
            typeRoot, 
            String filename,
            String relativePath,
            String fullPath,
            LazyPackage pkg)
        extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(filename, relativePath, fullPath, pkg)
        satisfies Source
        & JavaModelServicesConsumer<JavaClassRoot> {
    language = Language.java;
    
    shared actual default Unit clone() 
            => javaModelServices.newJavaCompilationUnit(typeRoot, relativePath, filename, fullPath, pkg);
    
    shared actual JavaClassRoot typeRoot;
    
    shared actual String sourceFileName =>
            filename;
    shared actual String sourceRelativePath =>
            relativePath;
    shared actual String sourceFullPath => 
            fullPath;
}
