import com.redhat.ceylon.ide.common.correct {
    CommonDocument
}

shared interface TextEdit of InsertEdit|DeleteEdit|ReplaceEdit {
    shared formal Integer start;
    shared formal Integer length;
    shared formal String text;
}

shared class InsertEdit(start, text) satisfies TextEdit {
    shared actual Integer start;
    length => 0;
    shared actual String text;
}

shared class DeleteEdit(start, length) satisfies TextEdit {
    shared actual Integer start;
    shared actual Integer length;
    text => "";
}

shared class ReplaceEdit(start, length, text) satisfies TextEdit {
    shared actual Integer start;
    shared actual Integer length;
    shared actual String text;
}

shared interface TextChange {
    shared formal void addEdit(TextEdit edit);
    
    shared formal void initMultiEdit();
 
    shared formal Boolean hasEdits;
 
    shared formal CommonDocument document;
}

shared interface CompositeChange {
    shared formal void addTextChange(TextChange change);
    shared formal Boolean hasChildren;    
}