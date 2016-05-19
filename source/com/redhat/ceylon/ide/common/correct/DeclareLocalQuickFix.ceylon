import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport,
    TypeCompletion
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared interface DeclareLocalQuickFix<Document,LinkedMode,CompletionResult>
        satisfies LinkedModeSupport<LinkedMode, Document, CompletionResult> {
    
    shared void enableLinkedMode(QuickFixData data, Tree.Term term, Document doc,
        TypeCompletion<CompletionResult,Document> completionManager) {
        
        if (exists type = term.typeModel) {
            value lm = newLinkedMode();
            value proposals = completionManager.getTypeProposals {
                document = doc;
                offset = data.node.startIndex.intValue();
                length = 5;
                infType = type;
                rootNode = data.rootNode;
                kind = "value";
            };
            addEditableRegion(lm, doc, data.node.startIndex.intValue(), 5, 0, proposals);
            installLinkedMode(doc, lm, this, -1, -1);
        }
    }
    
    shared void addDeclareLocalProposal(QuickFixData data) {
        value node = data.node;
        value st = nodes.findStatement(data.rootNode, node);
        
        if (is Tree.SpecifierStatement st) {
            value sst = st;
            value se = sst.specifierExpression;
            value bme = sst.baseMemberExpression;
            if (bme == node, is Tree.BaseMemberExpression bme) {
                if (exists e = se.expression, exists term = e.term) {
                    
                    value change = platformServices.createTextChange("Declare Local Value", data.phasedUnit);
                    change.initMultiEdit();
                    change.addEdit(InsertEdit(node.startIndex.intValue(), "value "));
                    value desc = "Declare local value '``bme.identifier.text``'";
                    
                    data.addDeclareLocalProposal(desc, change, term, bme);
                }
            }
        }
    }
}
