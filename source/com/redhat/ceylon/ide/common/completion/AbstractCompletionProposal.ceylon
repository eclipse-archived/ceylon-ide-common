import com.redhat.ceylon.ide.common.correct {
    DocumentChanges,
    ImportProposals
}

import java.lang {
    Character
}

shared abstract class AbstractCompletionProposal<IFile, CompletionResult, Document,InsertEdit,TextEdit,TextChange,Region>
        (offset, prefix, /*Image image,*/ description, text)
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & CommonCompletionProposal<Document,Region>
        given InsertEdit satisfies TextEdit {
    
    shared actual variable Integer offset;
    shared actual String prefix;
    shared actual String description;
    shared actual String text;
    
    shared actual variable Integer length = prefix.size;
    shared formal Boolean toggleOverwrite;
    shared formal ImportProposals<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange> importProposals;
    
    start() => offset - prefix.size;
    
    shared actual default Region getSelectionInternal(Document document) 
            => newRegion {
                start = start() + text.size;
                length = 0;
            };
    
    shared default void applyInternal(Document document) 
            => replaceInDoc {
                doc = document;
                start = start();
                length = lengthOf(document);
                newText = withoutDupeSemi(document);
            };
    
    shared TextEdit createEdit(Document document) 
            => newReplaceEdit {
                start = start();
                length = lengthOf(document);
                text = withoutDupeSemi(document);
            };
    
    shared Integer lengthOf(Document document) {
        if (("overwrite"==completionMode) != toggleOverwrite) {
            variable value length = prefix.size;
            variable value i = offset;
            value doclen = getDocLength(document);
            while (i < doclen
                && Character.isJavaIdentifierPart(getDocChar(document, i))) {
                length++;
                i++;
            }
            return length;
        } else {
            return this.length;
        }
    }
    
    shared actual String withoutDupeSemi(Document document) {
        if (text.endsWith(";"), 
            getDocLength(document)>offset && 
                    getDocChar(document, offset) == ';') {
            return text.initial(text.size - 1);
        }
        return text;
    }
}
