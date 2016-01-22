import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class JavaClassFile<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement> (
                typeRoot,
                String theFilename,
                String theRelativePath,
                String theFullPath,
                Package thePackage)
            extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
                    theFilename,
                    theRelativePath,
                    theFullPath,
                    thePackage)
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
