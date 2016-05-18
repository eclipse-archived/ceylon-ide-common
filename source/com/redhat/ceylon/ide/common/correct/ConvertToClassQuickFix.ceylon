import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}
import com.redhat.ceylon.ide.common.util {
    escaping
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    InsertEdit,
    CommonDocument
}

shared object convertToClassQuickFix {
    
    shared void addConvertToClassProposal(QuickFixData data, Tree.Declaration? declaration) {
        if (is Tree.ObjectDefinition declaration) {
            value desc = "Convert '" + declaration.declarationModel.name + "' to class";
            data.addConvertToClassProposal(desc, declaration);
        }
    }
}

shared interface AbstractConvertToClassProposal<CompletionResult,IDocument,LinkedMode>
        satisfies LinkedModeSupport<LinkedMode,IDocument,CompletionResult> {

    shared formal IDocument getNativeDocument(CommonDocument doc);
    
    shared void applyChanges(CommonDocument doc, Tree.ObjectDefinition node) {
        value declaration = node.declarationModel;
        value name = declaration.name;
        value initialName = escaping.toInitialUppercase(name);
        value change = platformServices.createTextChange("Convert to Class", doc);
        change.initMultiEdit();
        
        assert(is CommonToken tok = node.mainToken);
        value dstart = tok.startIndex;
        
        change.addEdit(ReplaceEdit(dstart, 6, "class"));
        value start = node.identifier.startIndex.intValue();
        value length = node.identifier.distance.intValue();
        
        change.addEdit(ReplaceEdit(start, length, initialName + "()"));
        value offset = node.endIndex.intValue();
        //TODO: handle actual object declarations
        value mods = if (declaration.shared) then "shared " else "";
        value ws = doc.defaultLineDelimiter + doc.getIndent(node);
        value impl = " = " + initialName + "();";
        value dec = ws + mods + initialName + " " + name;
        
        change.addEdit(InsertEdit(offset, dec + impl));
        
        change.apply();
        
        value lm = newLinkedMode();
        value nativeDoc = getNativeDocument(doc);
        
        addEditableRegions(lm, nativeDoc, 
            [start - 1, length, 0],
            [offset + ws.size + mods.size + 1, length, 1],
            [offset + dec.size + 4, length, 2]
        );
        
        installLinkedMode(nativeDoc, lm, this, -1, start - 1);
    }
}