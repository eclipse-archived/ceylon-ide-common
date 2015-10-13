import com.redhat.ceylon.ide.common.correct {
    DocumentChanges,
    ImportProposals
}

import java.lang {
    Character
}

shared abstract class AbstractCompletionProposal<IFile, CompletionResult, Document,InsertEdit,TextEdit,TextChange,Region>
        (shared actual variable Integer offset, shared actual String prefix, /*Image image,*/ shared actual String description, shared actual String text)
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & CommonCompletionProposal<Document,Region>
        given InsertEdit satisfies TextEdit {
    
    Integer length = prefix.size;

    shared formal Boolean toggleOverwrite;
    shared formal ImportProposals<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange> importProposals;
    
    shared actual default Region getSelectionInternal(Document document) {
        return newRegion(offset + text.size - prefix.size, 0);
    }
    
    shared default void applyInternal(Document document) {
        replaceInDoc(document, start(), lengthOf(document), withoutDupeSemi(document));
    }
    
    shared TextEdit createEdit(Document document) {
        return newReplaceEdit(start(), lengthOf(document), withoutDupeSemi(document));
    }
    
    shared Integer lengthOf(Document document) {
        value overwrite = completionMode;
        
        if ("overwrite".equals(overwrite) != toggleOverwrite) {
            variable value length = prefix.size;
            variable value i = offset;
            while (i < getDocLength(document) && Character.isJavaIdentifierPart(getDocChar(document, i).charValue())) {
                length++;
                i++;
            }
            return length;
        } else {
            return this.length;
        }
    }
    
    shared actual Integer start() {
        return offset - prefix.size;
    }
    
    shared actual String withoutDupeSemi(Document document) {
        if (text.endsWith(";"), getDocChar(document, offset) == ';') {
            return text.spanTo(text.size - 2);
        }
        return text;
    }
}
