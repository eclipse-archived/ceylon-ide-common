import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Scope,
    Interface,
    Reference,
    Unit,
    Type,
    Generic
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import ceylon.collection {
    MutableList
}
import java.util {
    List,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}
// see RefinementCompletionProposal
shared interface RefinementCompletion<IdeComponent, CompletionComponent, Document> {
    
    shared formal CompletionComponent newRefinementCompletionProposal(Integer offset, String prefix,
        Declaration dec, Reference? pr, Scope scope, IdeComponent cmp, Boolean isInterface,
        ClassOrInterface ci, Node node, Unit unit, Document doc, Boolean preamble);

    // see RefinementCompletionProposal.addRefinementProposal(...)
    shared void addRefinementProposal(Integer offset, Declaration dec, 
        ClassOrInterface ci, Node node, Scope scope, String prefix, 
        IdeComponent cpc, Document doc, 
        MutableList<CompletionComponent> result, Boolean preamble) {
        
        value isInterface = scope is Interface;
        Reference pr = getRefinedProducedReference(scope, dec);
        value unit = node.unit;
        
        result.add(newRefinementCompletionProposal(offset, prefix, dec, pr, scope, cpc, isInterface,
            ci, node, unit, doc, preamble));
    }
    
    // see getRefinedProducedReference(Scope scope, Declaration d)
    Reference getRefinedProducedReference(Scope scope, Declaration d) {
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
}