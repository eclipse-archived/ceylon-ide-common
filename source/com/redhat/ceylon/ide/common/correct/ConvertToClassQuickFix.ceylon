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

shared interface ConvertToClassQuickFix<Project,Data>
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, Tree.ObjectDefinition declaration);
 
    shared void addConvertToClassProposal(Data data, Tree.Declaration? declaration) {
        if (is Tree.ObjectDefinition declaration) {
            value desc = "Convert '" + declaration.declarationModel.name + "' to class";
            newProposal(data, desc, declaration);
        }
    }
}

shared interface AbstractConvertToClassProposal<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult,LinkedMode>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
                & LinkedModeSupport<LinkedMode,IDocument,CompletionResult>
            given Data satisfies QuickFixData<Project>
            given InsertEdit satisfies TextEdit {

    shared formal void performChange(TextChange change);
    
    shared void applyChanges(IDocument doc, Tree.ObjectDefinition node) {
        value declaration = node.declarationModel;
        value name = declaration.name;
        value initialName = escaping.toInitialUppercase(name);
        value change = newTextChange("Convert to Class", doc);
        initMultiEditChange(change);
        
        assert(is CommonToken tok = node.mainToken);
        value dstart = tok.startIndex;
        
        addEditToChange(change, newReplaceEdit(dstart, 6, "class"));
        value start = node.identifier.startIndex.intValue();
        value length = node.identifier.distance.intValue();
        
        addEditToChange(change, newReplaceEdit(start, length, initialName + "()"));
        value offset = node.endIndex.intValue();
        //TODO: handle actual object declarations
        value mods = if (declaration.shared) then "shared " else "";
        value ws = indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc);
        value impl = " = " + initialName + "();";
        value dec = ws + mods + initialName + " " + name;
        
        addEditToChange(change, newInsertEdit(offset, dec + impl));
        
        performChange(change);
        
        value lm = newLinkedMode();
        
        addEditableRegions(lm, doc, 
            [start - 1, length, 0],
            [offset + ws.size + mods.size + 1, length, 1],
            [offset + dec.size + 4, length, 2]
        );
        
        installLinkedMode(doc, lm, this, -1, start - 1);
    }
}