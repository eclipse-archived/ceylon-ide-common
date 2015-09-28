import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import java.util {
    Collection
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}

shared Tree.Term? getDeclareLocalTerm(Tree.CompilationUnit rootNode, Node node) {
    value st = nodes.findStatement(rootNode, node);
    
    if (is Tree.SpecifierStatement st) {
        value sst = st;
        value se = sst.specifierExpression;
        value bme = sst.baseMemberExpression;
        if (bme == node, is Tree.BaseMemberExpression bme) {
            if (exists e = se.expression, exists term = e.term) {
                return term;
            }
        }
    }
    
    return null;
}

shared interface DeclareLocalQuickFix<Document,InsertEdit,TextEdit,TextChange,LinkedMode,CompletionResult>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & LinkedModeSupport<LinkedMode, Document, CompletionResult>
        given InsertEdit satisfies TextEdit {
    
    shared formal void applyChange(Document doc, TextChange change);
    
    shared String getName(Node bme) {
        assert(is Tree.BaseMemberExpression bme);
        return "Declare local value '``bme.identifier.text``'";
    }
    
    shared void addDeclareLocalProposal(Tree.CompilationUnit rootNode, Node node,
        // Collection<ICompletionProposal> proposals, IFile file, CeylonEditor editor
        Document doc, TextChange change) {
        
        assert(exists term = getDeclareLocalTerm(rootNode, node));
        assert(is Tree.BaseMemberExpression node);
        
        addEditToChange(change, newInsertEdit(node.startIndex.intValue(), "value "));
        applyChange(doc, change);
        
        if (exists type = term.typeModel) {
            value lm = newLinkedMode();
            
            // TODO get proposals from TypeProposal
            addEditableRegion(lm, doc, node.startIndex.intValue(), 5, 0, []);
            installLinkedMode(doc, lm, this, -1, -1);
        }
    }
}
