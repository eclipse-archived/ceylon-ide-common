import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Class,
    Declaration,
    Type,
    TypeDeclaration,
    TypedDeclaration
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}

shared object types {
    
    shared Type? getResultType(Declaration d) {
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
    
    shared Type? getRequiredType(variable Tree.CompilationUnit rootNode, variable Node node, variable CommonToken token) {
        RequiredTypeVisitor rtv = RequiredTypeVisitor(node, token);
        rtv.visit(rootNode);
        return rtv.type;
    }
}
