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
            (super of BinaryWithSources).sourceFileName;
    shared actual String? sourceFullPath =>
            (super of BinaryWithSources).sourceFullPath;
    shared actual String? sourceRelativePath =>
            (super of BinaryWithSources).sourceRelativePath;
}
