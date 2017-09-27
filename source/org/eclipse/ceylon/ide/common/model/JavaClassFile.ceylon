import org.eclipse.ceylon.ide.common.platform {
    JavaModelServicesConsumer
}
import org.eclipse.ceylon.model.loader.model {
    LazyPackage
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit
}

shared abstract class JavaClassFile<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement> (
                typeRoot,
                String theFilename,
                String theRelativePath,
                String theFullPath,
                LazyPackage thePackage)
            extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
                    theFilename,
                    theRelativePath,
                    theFullPath,
                    thePackage)
            satisfies BinaryWithSources 
            & JavaModelServicesConsumer<JavaClassRoot> {
    
    shared actual JavaClassRoot typeRoot;

    shared actual Unit clone() 
            => javaModelServices.newJavaClassFile(typeRoot, relativePath, filename, fullPath, thePackage);
    
    binaryRelativePath => relativePath;
    
    shared actual String? sourceFileName =>
            (super of BinaryWithSources).sourceFileName;
    shared actual String? sourceFullPath =>
            (super of BinaryWithSources).sourceFullPath;
    shared actual String? sourceRelativePath =>
            (super of BinaryWithSources).sourceRelativePath;
}
