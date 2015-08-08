import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}

class FindArgumentVisitor(Node term) extends Visitor() {
    
    shared variable Tree.NamedArgument? declaration = null;
    variable Tree.NamedArgument? current = null;
    
    shared actual void visit(Tree.NamedArgument that) {
        Tree.NamedArgument? myOuter = current;
        current = that;
        super.visit(that);
        current = myOuter;
    }
    
    shared actual void visitAny(Node node) {
        if (node == term) {
            declaration = current;
        }
        
        if (!exists d = declaration) {
            super.visitAny(node);
        }
    }
}