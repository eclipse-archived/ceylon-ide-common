shared interface LinkedModeSupport<LinkedMode,Document,CompletionResult> {
    
    shared formal LinkedMode newLinkedMode();
    
    shared formal void addEditableRegion(LinkedMode lm, Document doc, Integer start, Integer len, Integer exitSeqNumber,
        CompletionResult[] proposals);
    
    shared formal void installLinkedMode(Document doc, LinkedMode lm, Object owner, Integer exitSeqNumber,
         Integer exitPosition);
}