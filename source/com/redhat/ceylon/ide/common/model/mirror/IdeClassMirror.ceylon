import com.redhat.ceylon.model.loader.mirror {
    ClassMirror
}

shared interface IdeClassMirror satisfies ClassMirror {
    shared formal String fileName;
    shared formal String fullPath;
    shared formal Boolean isBinary;
    shared formal Boolean isCeylon;    
}