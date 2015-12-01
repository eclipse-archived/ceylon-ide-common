import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.ide.common.correct {
    DocumentChanges
}

shared class Ref<Type>(shared variable Type val) {
    
}

shared interface CommonDocumentChanges
        satisfies DocumentChanges<Ref<String>,InsertEdit,TextEdit,TextChange> {
    
    shared actual void addEditToChange(TextChange tc, TextEdit te) {
        tc.addChange(te);
    }
    
    shared actual Ref<String> getDocumentForChange(TextChange tc) {
        return tc.document;
    }
    
    shared actual String getInsertedText(InsertEdit ie) {
        return ie.text;
    }
    
    shared actual void initMultiEditChange(TextChange tc) {
        // nothing
    }
    
    shared actual TextEdit newDeleteEdit(Integer start, Integer len) {
        return DeleteEdit(start, len);
    }
    
    shared actual InsertEdit newInsertEdit(Integer position, String string) {
        return InsertEdit(position, string);
    }
    
    shared actual TextEdit newReplaceEdit(Integer position, Integer length, String string) {
        return ReplaceEdit(position, length, string);
    }
}

shared class TextChange(shared Ref<String> document) {
    
    value changes = ArrayList<TextEdit>();
    
    shared void addChange(TextEdit change) {
        print("add change");
        changes.add(change);
    }
    
    shared void applyChanges() {
        Integer len = document.val.size;
        String text = document.val.spanTo(len - 1);
        document.val = mergeToCharArray(text, len, changes);
    }
    
    String mergeToCharArray(String text, Integer textLength, List<TextEdit> changes) {
        variable Integer newLength = textLength;
        for (change in changes) {
            newLength += change.text.size - (change.end - change.start);
        }
        value data = Array<Character>.ofSize(newLength, ' ');
        variable Integer oldEndOffset = textLength;
        variable Integer newEndOffset = data.size;
        variable Integer i = changes.size - 1;
        while (i >= 0) {
            assert(exists change = changes.get(i));
            Integer symbolsToMoveNumber = oldEndOffset - change.end;
            text.copyTo(data, change.end, newEndOffset - symbolsToMoveNumber, symbolsToMoveNumber);
            newEndOffset -= symbolsToMoveNumber;
            String changeSymbols = change.text;
            newEndOffset -= changeSymbols.size;
            changeSymbols.copyTo(data, 0, newEndOffset, changeSymbols.size);
            oldEndOffset = change.start;
            i--;
        }
        
        if (oldEndOffset > 0) {
            text.copyTo(data, 0, 0, oldEndOffset);
        }
        return String(data);
    }
    
    shared Boolean hasChanges { 
        print("has changes: " + (!changes.empty).string);
        return !changes.empty; 
    }
}

shared interface TextEdit {
    shared formal Integer start;
    shared formal Integer end;
    shared formal String text;
}

shared class InsertEdit(Integer position, shared actual String text) satisfies TextEdit {
    shared actual Integer start => position;
    shared actual Integer end => position;
}

shared class DeleteEdit(shared actual Integer start, Integer length) satisfies TextEdit {
    shared actual Integer end => start + length;
    shared actual String text => "";
}

shared class ReplaceEdit(shared actual Integer start, Integer length, shared actual String text) satisfies TextEdit {
    shared actual Integer end => start + length;
}
