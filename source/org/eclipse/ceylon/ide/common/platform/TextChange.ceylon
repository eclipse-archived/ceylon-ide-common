/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    ArrayList
}

shared interface TextEdit of InsertEdit|DeleteEdit|ReplaceEdit {
    shared formal Integer start;
    shared formal Integer length;
    shared formal String text;
    shared Integer end => start + length;
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
 
    shared formal void apply();
 
    shared formal Integer offset;
 
    shared formal Integer length;
}

shared class DefaultTextChange(shared actual DefaultDocument document) satisfies TextChange {
    
    value edits = ArrayList<TextEdit>();
    
    shared void addChange(TextEdit change) {
        edits.add(change);
    }
    
    shared actual void apply() {
        edits.sortInPlace((x, y) => x.start.compare(y.start));
        Integer len = document.text.size;
        String text = document.text;
        document.text = mergeToCharArray(text, len, edits);
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
    
    addEdit(TextEdit edit) => edits.add(edit);
    
    hasEdits => !edits.empty;
    
    shared actual void initMultiEdit() {}
    
    offset => if (exists e = edits.first) then e.start else 0;
    length => if (exists e = edits.first) then e.length else 0;
}

shared interface CompositeChange {
    shared formal void addTextChange(TextChange change);
    shared formal Boolean hasChildren;    
}

shared class DefaultCompositeChange(shared String desc) satisfies CompositeChange {
    
    value _changes = ArrayList<TextChange>();
    
    shared TextChange[] changes => _changes.sequence();
    
    addTextChange(TextChange change) => _changes.add(change);
    
    hasChildren => !_changes.empty;
}