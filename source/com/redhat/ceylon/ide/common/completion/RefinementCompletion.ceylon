import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Scope,
    Interface,
    Reference,
    Unit,
    Type,
    Generic,
    FunctionOrValue,
    Parameter
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
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

    // see RefinementCompletionProposal.addNamedArgumentProposal(...)
    shared formal CompletionComponent newNamedArgumentProposal(Integer offset, String prefix, 
        IdeComponent cmp, Tree.CompilationUnit unit, Declaration dec, Scope scope);
    
    shared formal CompletionComponent newInlineFunctionProposal(Integer offset, FunctionOrValue dec,
        Scope scope, Node node, String prefix, IdeComponent cmp, Document doc);

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
    
    shared void addInlineFunctionProposal(Integer offset, Declaration dec, Scope scope, Node node, String prefix,
            IdeComponent cmp, Document doc, variable MutableList<CompletionComponent> result) {

        if (dec.parameter, is FunctionOrValue dec) {
            result.add(newInlineFunctionProposal(offset, dec, scope, node, prefix, cmp, doc));
        }
    }

}