import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Class,
    Declaration,
    Type,
    TypeDeclaration,
    TypedDeclaration,
    ModelUtil,
    Parameter,
    ClassOrInterface
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import java.util {
    List
}

shared interface RequiredType {
    shared formal Type? type;
    shared formal String? parameterName;
    shared formal Parameter? parameter;
}

shared object types {
    
    shared Type? getResultType(Declaration? d) {
        switch (d)
        case (is TypeDeclaration) {
            if (is Class d, !d.abstract) {
                return d.type;
            }
            return null;
        } case (is TypedDeclaration) {
            return d.type;
        } else {
            return null;
        }
    }
        
    shared RequiredType getRequiredType(Tree.CompilationUnit rootNode, Node node, CommonToken? token) {
        value rtv = RequiredTypeVisitor(node, token);
        rtv.visit(rootNode);
        return rtv;
    }
    
    shared Declaration? getRefinedDeclaration(Declaration declaration) {
        //Reproduces the algorithm used to build the type hierarchy
        //first walk up the superclass hierarchy
        if (declaration.shared || declaration.actual,
            is ClassOrInterface container = declaration.container) {

            variable TypeDeclaration? dec = container;
            
            List<Type>? signature = ModelUtil.getSignature(declaration);
            Boolean variadic = ModelUtil.isVariadic(declaration);
            Declaration? refined = declaration.refinedDeclaration;
            while (exists d = dec) {
                if (exists extended = d.extendedType) {
                    value superDec = extended.declaration;
                    if (exists superMemberDec
                            = superDec.getDirectMember(declaration.name,
                                                        signature, variadic),
                        exists superRefined = superMemberDec.refinedDeclaration,
                        exists refined,
                        !ModelUtil.isAbstraction(superMemberDec),
                        superRefined == refined) {

                        return superMemberDec;
                    }
                    
                    dec = superDec;
                } else {
                    dec = null;
                }
            }
            
            //now look at the very top of the hierarchy, even if it is an interface
            value refinedDeclaration = refined;
            if (exists refinedDeclaration, declaration != refinedDeclaration) {
                
                assert (is TypeDeclaration decCont = declaration.container);
                assert (is TypeDeclaration refCont = refinedDeclaration.container);
                
                value directlyInheritedMembers = 
                        ModelUtil.getInterveningRefinements(declaration,
                            refinedDeclaration, decCont, refCont);
                
                directlyInheritedMembers.remove(refinedDeclaration);
                
                //TODO: do something for the case of
                //      multiple intervening interfaces?
                if (directlyInheritedMembers.size() == 1) {
                    //exactly one intervening interface
                    return directlyInheritedMembers[0];
                } else {
                    //no intervening interfaces
                    return refinedDeclaration;
                }
            }
        }
        
        return null;
    }

}
