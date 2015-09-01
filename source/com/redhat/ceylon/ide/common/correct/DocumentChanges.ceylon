shared interface DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        given InsertEdit satisfies TextEdit {

    shared formal void addEditToChange(TextChange change, TextEdit edit);

    shared formal IDocument getDocumentForChange(TextChange change);

    shared formal String getInsertedText(InsertEdit edit);

    shared formal void initMultiEditChange(TextChange change);

    shared formal TextEdit newDeleteEdit(Integer start, Integer stop);

    shared formal InsertEdit newInsertEdit(Integer position, String text);

    shared formal TextEdit newReplaceEdit(Integer start, Integer length, String text);

}