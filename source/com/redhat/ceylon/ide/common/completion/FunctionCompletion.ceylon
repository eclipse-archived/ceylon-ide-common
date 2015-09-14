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
        value stop = arg.stopIndex.intValue();
        value origin = primary.startIndex.intValue();
        value doc = cpc.document;
        value argText = cm.getDocumentSubstring(doc, start, stop - start + 1);
        value prefix = cm.getDocumentSubstring(doc, origin, offset - origin);
        variable String text = dec.getName(arg.unit) + "(" + argText + ")";
        
        if (is Functional dec, dec.declaredVoid) {
            text += ";";
        }
        value unit = cpc.rootNode.unit;
        value desc = getDescriptionFor(dec, unit) + "(...)";
        result.add(newFunctionCompletionProposal(offset, prefix, desc, text, dec, unit, cpc));
    }
}
