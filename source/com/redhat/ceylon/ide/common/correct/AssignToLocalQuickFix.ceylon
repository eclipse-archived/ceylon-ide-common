import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    TextChange,
    InsertEdit,
    LinkedMode
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    ModelUtil
}

shared object assignToLocalQuickFix satisfies LocalQuickFix<QuickFixData> {

    desc => "Assign expression to new local";
    
    newProposal(QuickFixData data, String desc) => data.addAssignToLocalProposal(desc);
}

shared interface AssignToLocalProposal<CompletionResult>
        satisfies AbstractLocalProposal {

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
    
    shared actual void addLinkedPositions(LinkedMode lm, Unit unit) {
        assert(exists initialName = names.first);
        
        value namez = toNameProposals(names.coalesced.sequence(), offset, unit, 1);
        lm.addEditableRegion(offset+6, initialName.size, 0, namez);
        
        value superTypes = getSupertypes(offset, unit, type, true, "value");
        lm.addEditableRegion(offset, 5, 1, toProposals(superTypes, offset, unit));
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
