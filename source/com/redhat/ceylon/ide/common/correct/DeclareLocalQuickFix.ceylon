import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared object declareLocalQuickFix {
    
    shared void enableLinkedMode(QuickFixData data, Tree.Term term) {
        
        if (exists type = term.typeModel) {
            value lm = platformServices.createLinkedMode(data.document);
            value proposals = typeCompletion.getTypeProposals {
                rootNode = data.rootNode;
                offset = data.node.startIndex.intValue();
                length = 5;
                infType = type;
                kind = "value";
            };
            lm.addEditableRegion(data.node.startIndex.intValue(), 5, 0, proposals);
            lm.install(this, -1, -1);
        }
    }
    
    shared void addDeclareLocalProposal(QuickFixData data) {
        value node = data.node;
        value st = nodes.findStatement(data.rootNode, node);
        
        if (is Tree.SpecifierStatement sst = st) {
            value se = sst.specifierExpression;
            value bme = sst.baseMemberExpression;
            if (bme == node,
                is Tree.BaseMemberExpression bme,
                exists e = se.expression,
                exists term = e.term) {
                
                value change = platformServices.document.createTextChange("Declare Local Value", data.phasedUnit);
                change.initMultiEdit();
                change.addEdit(InsertEdit(node.startIndex.intValue(), "value "));
                value desc = "Declare local value '``bme.identifier.text``'";
                
                value callback = void() {
                    change.apply();
                    enableLinkedMode(data, term);
                };
                data.addQuickFix(desc, callback);
            }
        }
    }
}
