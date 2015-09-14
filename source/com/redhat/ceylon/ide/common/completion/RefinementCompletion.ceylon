import ceylon.collection {
    MutableList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Scope,
    Interface,
    Reference,
    Type,
    Generic,
    FunctionOrValue
}

import java.util {
    List,
    ArrayList
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
// see RefinementCompletionProposal
shared interface RefinementCompletion<IdeComponent,IdeArtifact,CompletionComponent, Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared formal CompletionComponent newRefinementCompletionProposal(Integer offset, String prefix,
        Reference? pr, String desc, String text, IdeComponent cmp, Declaration dec, Scope scope);

    // see RefinementCompletionProposal.addNamedArgumentProposal(...)
    shared formal CompletionComponent newNamedArgumentProposal(Integer offset, String prefix, Reference? pr,
        String desc, String text, IdeComponent cmp, Declaration dec, Scope scope);
    
    shared formal CompletionComponent newInlineFunctionProposal(Integer offset, String prefix, Reference? pr,
        String desc, String text, IdeComponent cmp, Declaration dec, Scope scope);

    // see RefinementCompletionProposal.addRefinementProposal(...)
    shared void addRefinementProposal(Integer offset, Declaration dec, 
        ClassOrInterface ci, Node node, Scope scope, String prefix, IdeComponent cpc,
        MutableList<CompletionComponent> result, Boolean preamble, Indents<Document> indents,
        Boolean addParameterTypesInCompletions) {
        
        value isInterface = scope is Interface;
        Reference pr = getRefinedProducedReference(scope, dec);
        value unit = node.unit;
        value doc = cpc.document;
        
        value desc = getRefinementDescriptionFor(dec, pr, unit);
        value text = getRefinementTextFor(dec, pr, unit, isInterface, ci, 
                        indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc), 
                        true, preamble, indents, addParameterTypesInCompletions);
        
        result.add(newRefinementCompletionProposal(offset, prefix, pr, desc, text, cpc, dec, scope));
    }

    // see getRefinedProducedReference(Scope scope, Declaration d)
    shared Reference getRefinedProducedReference(Scope scope, Declaration d) {
        return refinedProducedReference(scope.getDeclaringType(d), d);
    }
    
    // see refinedProducedReference(Type outerType, Declaration d)
    Reference refinedProducedReference(Type outerType, 
        Declaration d) {
        List<Type> params = ArrayList<Type>();
        if (is Generic d) {
            for (tp in CeylonIterable(d.typeParameters)) {
                params.add(tp.type);
            }
        }
        return d.appliedReference(outerType, params);
    }
    
    shared void addNamedArgumentProposal(Integer offset, String prefix, IdeComponent cpc,
        MutableList<CompletionComponent> result, Declaration dec, Scope scope) {
        
        value unit = cpc.rootNode.unit;
        value desc = getDescriptionFor(dec, unit);
        value text = getTextFor(dec, unit) + " = nothing;";
        
        result.add(newNamedArgumentProposal(offset, prefix, dec.reference, desc, text, cpc, dec, scope));
    }


    shared void addInlineFunctionProposal(Integer offset, Declaration dec, Scope scope, Node node, String prefix,
            IdeComponent cmp, Document doc, variable MutableList<CompletionComponent> result, Indents<Document> indents) {

        if (dec.parameter, is FunctionOrValue dec) {
            value p = dec.initializerParameter;
            value unit = node.unit;
            value desc = getInlineFunctionDescriptionFor(p, null, unit);
            value text = getInlineFunctionTextFor(p, null, unit, 
                    indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc));
            
            result.add(newInlineFunctionProposal(offset, prefix, dec.reference, desc, text, cmp, dec, scope));
        }
    }

}