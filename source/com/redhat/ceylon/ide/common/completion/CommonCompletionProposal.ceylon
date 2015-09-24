import java.lang {
    Character
}
shared interface CommonCompletionProposal<Document,Region> {
    
    shared formal String withoutDupeSemi(Document document);
    
    shared formal Integer start();
    
    shared formal Region getSelectionInternal(Document document);
    
    shared formal String completionMode;

    shared formal String prefix;
    shared formal Integer offset;
    shared formal String description;
    shared formal String text;
    
    shared formal void replaceInDoc(Document doc, Integer start, Integer length, String newText);
    shared formal Integer getDocLength(Document doc);
    shared formal Character getDocChar(Document doc, Integer offset);
    shared formal String getDocSpan(Document doc, Integer start, Integer length);
    shared formal Region newRegion(Integer start, Integer length);
    shared formal Integer getRegionStart(Region region);
    shared formal Integer getRegionLength(Region region);
}