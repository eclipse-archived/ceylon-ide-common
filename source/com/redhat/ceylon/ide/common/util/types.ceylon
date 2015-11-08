import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Class,
    Declaration,
    Type,
    TypeDeclaration,
    TypedDeclaration,
    ModelUtil
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
}

shared object types {
    
    shared Type? getResultType(Declaration? d) {
        if (is TypeDeclaration d) {
            if (is Class d, !d.abstract) {
                return (d).type;
            }
            return null;
        } else if (is TypedDeclaration d) {
            return (d).type;
        } else {
            return null;
        }
    }
        
    shared RequiredType getRequiredType(variable Tree.CompilationUnit rootNode, variable Node node, variable CommonToken token) {
        RequiredTypeVisitor rtv = RequiredTypeVisitor(node, token);
        rtv.visit(rootNode);
        return rtv;
    }
    
    shared Declaration? getRefinedDeclaration(Declaration declaration) {
        //Reproduces the algorithm used to build the type hierarchy
        //first walk up the superclass hierarchy
        if (declaration.classOrInterfaceMember, declaration.shared) {
            assert (is TypeDeclaration? _dec = declaration.container);
            variable TypeDeclaration? dec = _dec;
            
            List<Type>? signature = ModelUtil.getSignature(declaration);
            Declaration? refined = declaration.refinedDeclaration;
            while (exists d = dec) {
                if (exists extended = d.extendedType) {
                    value superDec = extended.declaration;
                    Declaration? superMemberDec = superDec.getDirectMember(declaration.name, signature, false);
                    if (exists superMemberDec) {
                        Declaration? superRefined = superMemberDec.refinedDeclaration;
                        if (exists superRefined, exists refined,
                            !ModelUtil.isAbstraction(superMemberDec),
                            superRefined.equals(refined)) {
                            
                            return superMemberDec;
                        }
                    }
                    
                    dec = superDec;
                } else {
                    dec = null;
                }
            }
            
            //now look at the very top of the hierarchy, even if it is an interface
            value refinedDeclaration = refined;
            if (exists refinedDeclaration,
                !declaration.equals(refinedDeclaration)) {
                
                assert(is TypeDeclaration? decCont = declaration.container);
                assert(is TypeDeclaration? refCont = refinedDeclaration.container);
                
                value directlyInheritedMembers = 
                        ModelUtil.getInterveningRefinements(declaration.name,
                    signature, refinedDeclaration,
                    decCont, refCont);
                
                directlyInheritedMembers.remove(refinedDeclaration);
                
                //TODO: do something for the case of
                //      multiple intervening interfaces?
                if (directlyInheritedMembers.size() == 1) {
                    //exactly one intervening interface
                    return directlyInheritedMembers.get(0);
                } else {
                    //no intervening interfaces
                    return refinedDeclaration;
                }
            }
        }
        
        return null;
    }

}
