import com.redhat.ceylon.ide.common.correct {
    CommonDocument
}

shared interface TextEdit of InsertEdit|DeleteEdit|ReplaceEdit {
    
}

shared class InsertEdit(shared Integer position, shared String text) satisfies TextEdit {

}

shared class DeleteEdit(shared Integer start, shared Integer length) satisfies TextEdit {

}

shared class ReplaceEdit(shared Integer start, shared Integer length, shared String text) satisfies TextEdit {

}

shared interface TextChange {
    shared formal void addEdit(TextEdit edit);
    
    shared formal void addChangesFrom(TextChange other);
 
    shared formal void initMultiEdit();
 
    shared formal Boolean hasEdits;
 
    shared formal CommonDocument document;
}