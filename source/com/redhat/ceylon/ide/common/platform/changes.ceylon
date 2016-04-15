import com.redhat.ceylon.ide.common.correct {
    CommonDocument
}

shared interface TextEdit of InsertEdit|DeleteEdit|ReplaceEdit {
    shared formal Integer start;
    shared formal Integer length;
    shared formal String text;
}

shared class InsertEdit(shared actual Integer start, shared actual String text) satisfies TextEdit {
    length => 0;
}

shared class DeleteEdit(shared actual Integer start, shared actual Integer length) satisfies TextEdit {
    text => "";
}

shared class ReplaceEdit(shared actual Integer start, 
    shared actual Integer length, shared actual String text) satisfies TextEdit {

}

shared interface TextChange {
    shared formal void addEdit(TextEdit edit);
    
    shared formal void addChangesFrom(TextChange other);
 
    shared formal void initMultiEdit();
 
    shared formal Boolean hasEdits;
 
    shared formal CommonDocument document;
}