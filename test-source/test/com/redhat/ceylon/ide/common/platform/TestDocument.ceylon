import com.redhat.ceylon.ide.common.correct {
    CommonDocument
}
import ceylon.test {
    test,
    assertEquals
}

shared class TestDocument(shared variable String text) satisfies CommonDocument {
    
    value lines = text.linesWithBreaks.sequence();
    
    getDefaultLineDelimiter() => "\n";
    
    getLineContent(Integer line) => lines[line - 1] else "";
    
    getLineStartOffset(Integer line)
            => if (line == 1)
               then 0
               else lines[0..line - 2].fold(0)((size, str) => size + str.size);
    
    getLineEndOffset(Integer line)
            => lines[0..line - 1].fold(0)((size, str) => size + str.size);
    
    shared actual Integer getLineOfOffset(Integer offset) {
        variable value size = 0;
        
        for (i in 0..lines.size) {
            assert(exists line = lines[i]);
            if (size < offset) {
                size += line.size;
            } else {
                return i;
            }
        }
        
        return lines.size;
    }
    
    getText(Integer offset, Integer length)
            => text.substring(offset, offset + length);
}

test void testDocument() {
    value doc = TestDocument("This is a text
                              that spans
                              multiple
                              lines.");
    
    assertEquals(doc.getLineContent(1), "This is a text\n");
    assertEquals(doc.getLineContent(4), "lines.");
    
    assertEquals(doc.getLineStartOffset(1), 0);
    assertEquals(doc.getLineEndOffset(1), 15);

    assertEquals(doc.getLineStartOffset(2), 15);
    assertEquals(doc.getLineEndOffset(2), 26);
}