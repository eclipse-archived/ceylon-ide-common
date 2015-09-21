import com.redhat.ceylon.ide.common.correct {
    DocumentChanges,
    ImportProposals
}

import java.lang {
    Character
}

shared abstract class AbstractCompletionProposal<IFile, CompletionResult, Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit {
    
    String text;
    //Image image;
    String prefix;
    String description;
    Integer offset;
    Integer length;
    variable Boolean toggleOverwrite = false;
    String currentPrefix;
    
    shared formal ImportProposals<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange> importProposals;

    shared new (Integer offset, String prefix, /*Image image,*/ String desc, String text) {
        this.text = text;
        //this.image = image;
        this.offset = offset;
        this.prefix = prefix;
        currentPrefix = prefix;
        this.length = prefix.size;
        this.description = desc;
    }
    
    //shared actual Image getImage() {
    //    return image;
    //}
    
    shared formal void replaceInDoc(Document doc, Integer start, Integer length, String newText);
    shared formal Integer getDocLength(Document doc);
    shared formal Character getDocChar(Document doc, Integer offset);
    shared formal String getDocSpan(Document doc, Integer start, Integer length);
    shared formal Region newRegion(Integer start, Integer length);

    shared default Region getSelection(Document document) {
        return newRegion(offset + text.size - prefix.size, 0);
    }
    
    shared void apply(Document document) {
        replaceInDoc(document, start(), lengthOf(document), withoutDupeSemi(document));
    }
    
    shared TextEdit createEdit(Document document) {
        return newReplaceEdit(start(), lengthOf(document), withoutDupeSemi(document));
    }
    
    shared formal String completionMode;
    
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
    
    shared Integer start() {
        return offset - prefix.size;
    }
    
    shared String withoutDupeSemi(Document document) {
        if (text.endsWith(";"), getDocChar(document, offset) == ';') {
            return text.span(0, text.size - 1);
        }
        return text;
    }
    
    shared String getDisplayString() {
        return description;
    }
}
