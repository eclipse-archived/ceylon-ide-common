import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import ceylon.collection {
    MutableList
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Unit
}
import java.util {
    HashSet
}
shared interface FunctionCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {

    shared formal CompletionResult newFunctionCompletionProposal(Integer offset, String prefix,
           String desc, String text, Declaration dec, Unit unit, IdeComponent cmp);
    
    shared void addFunctionProposal(Integer offset, IdeComponent cpc, Tree.Primary primary, 
            MutableList<CompletionResult> result, Declaration dec,
            IdeCompletionManager<IdeComponent, IdeArtifact, CompletionResult, Document> cm) {

        variable Tree.Term arg = primary;
        while (is Tree.Expression a = arg) {
            arg = a.term;
        }

        value start = arg.startIndex.intValue();
        value stop = arg.endIndex.intValue();
        value origin = primary.startIndex.intValue();
        value doc = cpc.document;
        value argText = cm.getDocumentSubstring(doc, start, stop - start);
        value prefix = cm.getDocumentSubstring(doc, origin, offset - origin);
        variable String text = dec.getName(arg.unit) + "(" + argText + ")";
        
        if (is Functional dec, dec.declaredVoid) {
            text += ";";
        }
        value unit = cpc.lastCompilationUnit.unit;
        value desc = getDescriptionFor(dec, unit) + "(...)";
        result.add(newFunctionCompletionProposal(offset, prefix, desc, text, dec, unit, cpc));
    }
}

shared abstract class FunctionCompletionProposal<CompletionResult,IFile,Document,InsertEdit,TextEdit,TextChange,Region>  
        (Integer _offset, String prefix, String desc, String text, Declaration declaration, Tree.CompilationUnit rootNode)
        extends AbstractCompletionProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region>
        (_offset, prefix, desc, text)
        given InsertEdit satisfies TextEdit {
    
    shared TextChange createChange(TextChange change, Document document) {
        initMultiEditChange(change);
        value decs = HashSet<Declaration>();
        importProposals.importDeclaration(decs, declaration, rootNode);
        value il = importProposals.applyImports(change, decs, rootNode, document);
        addEditToChange(change, createEdit(document));
        offset += il;
        return change;
    }
}
