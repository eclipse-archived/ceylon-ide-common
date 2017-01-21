import com.redhat.ceylon.model.loader.mirror {
    PackageMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared class JPackageMirror(Package modelPackage) satisfies PackageMirror {
    shared actual String qualifiedName = modelPackage.nameAsString;
}