import com.redhat.ceylon.ide.common.platform {
    DefaultDocument,
    CommonDocument
}

import ceylon.test {
    test,
    assertEquals
}



test void testDocument() {
    value doc = DefaultDocument("This is a text
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