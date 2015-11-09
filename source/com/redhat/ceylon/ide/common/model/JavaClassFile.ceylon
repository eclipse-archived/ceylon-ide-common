import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class JavaClassFile<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement> (
                typeRoot,
                String filename,
                String relativePath,
                String fullPath,
                Package \ipackage)
            extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
                    filename,
                    relativePath,
                    fullPath,
                    \ipackage)
            satisfies BinaryWithSources {
    
    shared actual JavaClassRoot typeRoot;
    
    binaryRelativePath => relativePath;
    
    shared actual String? sourceFileName =>
            (this of BinaryWithSources).sourceFileName;
    shared actual String? sourceFullPath =>
            (this of BinaryWithSources).sourceFullPath;
    shared actual String? sourceRelativePath =>
            (this of BinaryWithSources).sourceRelativePath;
}
