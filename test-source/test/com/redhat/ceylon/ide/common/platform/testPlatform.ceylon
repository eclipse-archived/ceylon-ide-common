import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.correct {
    ImportProposals,
    CommonDocument
}
import com.redhat.ceylon.ide.common.platform {
    PlatformServices,
    VfsServices,
    IdeUtils,
    ModelServices,
    CompositeChange,
    TextChange,
    TextEdit
}
import com.redhat.ceylon.ide.common.util {
    Indents,
    unsafeCast
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}

shared object testPlatform satisfies PlatformServices {
    createCompositeChange(String desc)
            => TestCompositeChange(desc);
    
    createTextChange(String desc, CommonDocument|PhasedUnit input)
            => if (is TestDocument input) then TestTextChange(input) else nothing;
    
    shared actual ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange> importProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange>() => nothing;
    
    shared actual Indents<IDocument> indents<IDocument>()
            => unsafeCast<Indents<IDocument>>(testIndents);
    
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    shared actual IdeUtils utils() => nothing;
    
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;

}

shared object testIndents satisfies Indents<TestDocument> {
    getDefaultLineDelimiter(TestDocument? document) 
            => document?.getDefaultLineDelimiter() else "\n";
    
    getLine(Node node, TestDocument doc)
            => doc.getLineContent(doc.getLineOfOffset(node.startIndex.intValue()));
    
    indentSpaces => 4;
    
    indentWithSpaces => true;
}

shared class TestCompositeChange(shared String desc) satisfies CompositeChange {
    
    value _changes = ArrayList<TextChange>();
    
    shared TextChange[] changes => _changes.sequence();
    
    addTextChange(TextChange change) => _changes.add(change);
    
    hasChildren => !_changes.empty;
}

shared class TestTextChange(shared actual TestDocument document) satisfies TextChange {
    
    value edits = ArrayList<TextEdit>();
    
    shared void addChange(TextEdit change) {
        print("add change");
        edits.add(change);
    }
    
    shared void applyChanges() {
        Integer len = document.text.size;
        String text = document.text.spanTo(len - 1);
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
}
