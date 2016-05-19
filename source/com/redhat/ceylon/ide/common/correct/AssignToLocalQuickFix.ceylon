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
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    TextChange,
    InsertEdit
}

shared interface AssignToLocalQuickFix<in Data>
        satisfies LocalQuickFix<Data>
        given Data satisfies QuickFixData {

    desc => "Assign expression to new local";

}

shared interface AssignToLocalProposal<IDocument,CompletionResult,LinkedMode>
        satisfies AbstractLocalProposal<IDocument,LinkedMode>
                & LinkedModeSupport<LinkedMode,IDocument,CompletionResult> {

    shared actual TextChange createChange(QuickFixData data, Node expanse, Integer endIndex) {
        value change = platformServices.createTextChange("Assign to Local", data.phasedUnit);
        change.initMultiEdit();
        value name = names.first else "<unknown>";
        change.addEdit(InsertEdit(offset, "value " + name + " = "));
        value terminal = expanse.endToken.text;
        
        if (!terminal.equals(";")) {
            change.addEdit(InsertEdit(endIndex, ";"));
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
