import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    TextEdit,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

import java.lang {
    Character
}

shared abstract class AbstractCompletionProposal
        (offset, prefix, /*Image image,*/ description, text)
        satisfies CommonCompletionProposal {

    shared actual variable Integer offset;
    shared actual String prefix;
    shared actual String description;
    shared actual String text;
    
    shared actual variable Integer length = prefix.size;
    shared formal Boolean toggleOverwrite;

    shared actual default DefaultRegion getSelectionInternal(CommonDocument document) 
            => DefaultRegion {
                start = start + text.size;
                length = 0;
            };
    
    shared default void applyInternal(CommonDocument document) 
            => replaceInDoc {
                doc = document;
                start = start;
                length = lengthOf(document);
                newText = withoutDupeSemi(document);
            };
    
    shared TextEdit createEdit(CommonDocument document) 
            => ReplaceEdit {
                start = start;
                length = lengthOf(document);
                text = withoutDupeSemi(document);
            };
    
    shared Integer lengthOf(CommonDocument document) {
        if (("overwrite"==completionMode) != toggleOverwrite) {
            variable value length = prefix.size;
            variable value i = offset;
            value doclen = document.size;
            while (i < doclen
                && Character.isJavaIdentifierPart(document.getChar(i))) {
                length++;
                i++;
            }
            return length;
        } else {
            return this.length;
        }
    }
    
    shared actual String withoutDupeSemi(CommonDocument document) {
        if (text.endsWith(";"), 
            document.size>offset && 
                    document.getChar(offset) == ';') {
            return text.initial(text.size - 1);
        }
        return text;
    }
}
