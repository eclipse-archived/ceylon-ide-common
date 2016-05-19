shared abstract class LinkedMode(CommonDocument document) {
    
    shared formal void addEditableRegion(
        Integer start,
        Integer length,
        Integer exitSeqNumber,
        Anything proposals // TODO create an abstraction of Proposal
    );

    shared formal void addEditableGroup(
        "[start, length, exitSeqNumber]"
        [Integer, Integer, Integer]+ positions
    );

    shared formal void install(
        Object owner,
        Integer exitSeqNumber,
        Integer exitPosition
    );
}

shared class NoopLinkedMode(CommonDocument document) extends LinkedMode(document) {
    
    addEditableRegion(Integer start, Integer length, Integer exitSeqNumber, Anything proposals)
        => noop();
    
    addEditableGroup(Integer[3]+ positions) => noop();
    
    install(Object owner, Integer exitSeqNumber, Integer exitPosition) => noop();
}
