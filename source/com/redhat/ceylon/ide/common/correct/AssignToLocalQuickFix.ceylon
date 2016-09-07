import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.completion {
    ProposalsHolder
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

shared interface AssignToLocalProposal
        satisfies AbstractLocalProposal {

    shared actual TextChange createChange(QuickFixData data, Node expanse, Integer endIndex) {
        value change =
                platformServices.document
                    .createTextChange("Assign to Local", data.phasedUnit);
        change.initMultiEdit();
        value name = names.first else "<unknown>";
        change.addEdit(InsertEdit {
            start = offset;
            text = "value ``name`` = ";
        });
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
        assert (exists initialName = names.first);
        
        value namez = platformServices.completion.createProposalsHolder();
        toNameProposals(names.coalesced.sequence(), namez, offset, unit, 1);
        lm.addEditableRegion(offset+6, initialName.size, 0, namez);
        
        value superTypes = getSupertypes(offset, unit, type, true, "value");
        value superTypesProposals = platformServices.completion.createProposalsHolder();
        toProposals(superTypes, superTypesProposals, offset, unit);
        lm.addEditableRegion(offset, 5, 1, superTypesProposals);
    }

    // TODO move to CompletionServices
    shared formal void toNameProposals(String[] names, ProposalsHolder proposals,
        Integer offset, Unit unit, Integer seq);
    
    shared formal void toProposals(<String|Type>[] types, ProposalsHolder proposals,
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
        value supertypes
                = ModelUtil.isTypeUnknown(type) || type.typeConstructor
                then []
                else CeylonList(td.supertypeDeclarations)
                    .sequence()
                    .sort((x, y) {
                        if (x.inherits(y)) {
                            return larger;
                        }
                        if (y.inherits(x)) {
                            return smaller;
                        }
                        return y.name<=>x.name;
                    });
        
        typeProposals.addAll(supertypes.reversed.map((td) => type.getSupertype(td)));
        
        return typeProposals.sequence();
    }
}
