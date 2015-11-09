import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared abstract class JavaCompilationUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(
            typeRoot, 
            String filename,
            String relativePath,
            String fullPath,
            Package pkg)
        extends JavaUnit<NativeProject, NativeFolder, NativeFile, JavaClassRoot, JavaElement>(filename, relativePath, fullPath, pkg) {
    shared actual JavaClassRoot typeRoot;
    
    shared actual String sourceFileName =>
            filename;
    shared actual String sourceRelativePath =>
            relativePath;
    shared actual String sourceFullPath => 
            fullPath;
}
