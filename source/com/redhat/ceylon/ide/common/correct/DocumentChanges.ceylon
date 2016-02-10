shared interface DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        given InsertEdit satisfies TextEdit {

    shared formal void addEditToChange(TextChange change, TextEdit edit);

    shared formal IDocument getDocumentForChange(TextChange change);

    shared formal String getInsertedText(InsertEdit edit);

    shared formal void initMultiEditChange(TextChange change);

    shared formal TextEdit newDeleteEdit(Integer start, Integer length);

    shared formal InsertEdit newInsertEdit(Integer position, String text);

    shared formal TextEdit newReplaceEdit(Integer start, Integer length, String text);

    shared formal Boolean hasChildren(TextChange change);
    
    "Returns a subset of the `doc` from offset `start` to `start + length`"
    shared formal String getDocContent(IDocument doc, Integer start, Integer length);
}
