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
import com.redhat.ceylon.ide.common.correct {
    importProposals
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    TextChange
}
shared interface FunctionCompletion<CompletionResult> {

    shared formal CompletionResult newFunctionCompletionProposal(Integer offset, String prefix,
           String desc, String text, Declaration dec, Unit unit, LocalAnalysisResult cmp);
    
    shared void addFunctionProposal(Integer offset, LocalAnalysisResult cpc, Tree.Primary primary, 
            MutableList<CompletionResult> result, Declaration dec) {

        variable Tree.Term arg = primary;
        while (is Tree.Expression a = arg) {
            arg = a.term;
        }

        value start = arg.startIndex.intValue();
        value stop = arg.endIndex.intValue();
        value origin = primary.startIndex.intValue();
        value doc = cpc.commonDocument;
        value argText = doc.getText(start, stop - start);
        value prefix = doc.getText(origin, offset - origin);
        variable String text = dec.getName(arg.unit) + "(" + argText + ")";
        
        if (is Functional dec, dec.declaredVoid) {
            text += ";";
        }
        value unit = cpc.lastCompilationUnit.unit;
        value desc = getDescriptionFor(dec, unit) + "(...)";
        result.add(newFunctionCompletionProposal(offset, prefix, desc, text, dec, unit, cpc));
    }
}

shared abstract class FunctionCompletionProposal  
        (Integer _offset, String prefix, String desc, String text, Declaration declaration, Tree.CompilationUnit rootNode)
        extends AbstractCompletionProposal(_offset, prefix, desc, text) {
    
    shared TextChange createChange(CommonDocument document) {
        value change = platformServices.createTextChange("Complete Invocation", document);
        value decs = HashSet<Declaration>();
        importProposals.importDeclaration(decs, declaration, rootNode);
        value il = importProposals.applyImports(change, decs, rootNode, document);
        change.addEdit(createEdit(document));
        offset += il;
        return change;
    }
}
