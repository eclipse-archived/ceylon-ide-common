import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared interface DeclareLocalQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,LinkedMode,CompletionResult,Project,Data,Region>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & AbstractQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
                & LinkedModeSupport<LinkedMode, Document, CompletionResult>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData {
    
    shared void enableLinkedMode(Data data, Tree.Term term, TextChange change) {
        if (exists type = term.typeModel) {
            value lm = newLinkedMode();
            value doc = getDocumentForChange(change);
            value proposals = completionManager.getTypeProposals(doc, data.node.startIndex.intValue(), 5, type, data.rootNode, "value");
            addEditableRegion(lm, doc, data.node.startIndex.intValue(), 5, 0, proposals);
            installLinkedMode(doc, lm, this, -1, -1);
        }
    }
    
    shared formal void newDeclareLocalQuickFix(Data data, String desc, TextChange change, 
        Tree.Term term, Tree.BaseMemberExpression bme);
    
    shared void addDeclareLocalProposal(Data data, IFile file) {
        value node = data.node;
        value st = nodes.findStatement(data.rootNode, node);
        
        if (is Tree.SpecifierStatement st) {
            value sst = st;
            value se = sst.specifierExpression;
            value bme = sst.baseMemberExpression;
            if (bme == node, is Tree.BaseMemberExpression bme) {
                if (exists e = se.expression, exists term = e.term) {
                    
                    value change = newTextChange("Declare Local Value", file);
                    initMultiEditChange(change);
                    addEditToChange(change, newInsertEdit(node.startIndex.intValue(), "value "));
                    value desc = "Declare local value '``bme.identifier.text``'";
                    
                    newDeclareLocalQuickFix(data, desc, change, term, bme);
                }
            }
        }
    }
}
