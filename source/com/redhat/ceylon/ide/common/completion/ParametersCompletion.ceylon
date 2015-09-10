import java.util {
    List
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Functional
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import ceylon.collection {
    MutableList
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
shared interface ParametersCompletion<IdeComponent,IdeArtifact,CompletionComponent,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {

    shared formal Boolean showParameterTypes;
    
    shared formal CompletionComponent newParametersCompletionProposal(Integer offset, 
        Type type, List<Type> argTypes, 
        Node node, IdeComponent cmp);
    
    // see ParametersCompletionProposal.addParametersProposal(final int offset, Node node, final List<ICompletionProposal> result, CeylonParseController cpc)
    shared void addParametersProposal(Integer offset, Tree.Term node, MutableList<CompletionComponent> result, IdeComponent cmp) {
        value condition = if (is Tree.StaticMemberOrTypeExpression node) then !(node.declaration is Functional) else true;
        
        if (condition, exists unit = node.unit, exists type = node.typeModel) {
            value cd = unit.callableDeclaration;
            
            if (type.classOrInterface, type.declaration.equals(cd)) {
                value argTypes = unit.getCallableArgumentTypes(type);
                
                result.add(newParametersCompletionProposal(offset, type, argTypes, node, cmp));
            }
        }
    }
}