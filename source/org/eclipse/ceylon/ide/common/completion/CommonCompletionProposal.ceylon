import org.eclipse.ceylon.ide.common.platform {
    CommonDocument
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface CommonCompletionProposal {
    
    shared formal String withoutDupeSemi(CommonDocument document);
    
    shared formal DefaultRegion getSelectionInternal(CommonDocument document);
    
    shared formal String completionMode;

    shared formal String prefix;
    shared formal Integer offset;
    shared Integer start => offset - prefix.size;

    shared formal String description;
    shared formal String text;
    shared formal variable Integer length;
    
    shared formal void replaceInDoc(CommonDocument doc, Integer start, Integer length, String newText);
}