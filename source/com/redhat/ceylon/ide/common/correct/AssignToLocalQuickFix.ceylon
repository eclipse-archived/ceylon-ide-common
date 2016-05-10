import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    ModelUtil
}
import ceylon.interop.java {
    CeylonList
}
import ceylon.collection {
    ArrayList
}

shared interface AssignToLocalQuickFix<IFile,Data>
        satisfies LocalQuickFix<IFile,Data>
        given Data satisfies QuickFixData {

    desc => "Assign expression to new local";

}

shared interface AssignToLocalProposal<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult,LinkedMode>
        satisfies AbstractLocalProposal<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult,LinkedMode>
                & LinkedModeSupport<LinkedMode,IDocument,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared actual TextChange createChange(IFile file, Node expanse, Integer endIndex) {
        value change = newTextChange("Assign to Local", file);
        initMultiEditChange(change);
        value name = names.first else "<unknown>";
        addEditToChange(change, newInsertEdit(offset, "value " + name + " = "));
        value terminal = expanse.endToken.text;
        
        if (!terminal.equals(";")) {
            addEditToChange(change, newInsertEdit(endIndex, ";"));
            exitPos = endIndex + 1;
        } else {
            exitPos = endIndex;
        }
        
        return change;
    }
    
    shared actual LinkedMode? addLinkedPositions(IDocument doc, Unit unit) {
        value lm = newLinkedMode();
        
        assert(exists initialName = names.first);
        
        value namez = toNameProposals(names.coalesced.sequence(), offset, unit, 1);
        addEditableRegion(lm, doc, offset+6, initialName.size, 0, namez);
        
        value superTypes = getSupertypes(offset, unit, type, true, "value");
        addEditableRegion(lm, doc, offset, 5, 1, toProposals(superTypes, offset, unit));
        
        return lm;
    }

    shared formal CompletionResult[] toNameProposals(String[] names,
        Integer offset, Unit unit, Integer seq);
    
    shared formal CompletionResult[] toProposals(<String|Type>[] types,
        Integer offset, Unit unit);

    // Adapted from LinkedModeCompletionProposal.getSupertypeProposals()
    <String|Type>[] getSupertypes(Integer offset, Unit unit, Type? type,
        Boolean includeValue, String kind) {
        
        if (!exists type) {
            return empty;
        }
        
        value typeProposals = ArrayList<String|Type>();
        
        if (includeValue) {
            typeProposals.add(kind);
        }
        if (type.typeConstructor || type.union || type.intersection) {
            typeProposals.add(type);
        }

        value td = type.declaration;
        value supertypes = if (ModelUtil.isTypeUnknown(type) || type.typeConstructor)
                           then empty
                           else CeylonList(td.supertypeDeclarations)
                                .sequence()
                                .sort((x, y) {
                                    if (x.inherits(y)) {
                                        return larger;
                                    }
                                    if (y.inherits(x)) {
                                        return smaller;
                                    }
                                    return y.name.compare(x.name);
                                });
        
        typeProposals.addAll(supertypes.reversed.map((td) => type.getSupertype(td)));
        
        return typeProposals.sequence();
    }
}
