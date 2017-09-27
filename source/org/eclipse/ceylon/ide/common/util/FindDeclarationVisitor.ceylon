import org.eclipse.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
class FindDeclarationVisitor(Node term) extends Visitor() {
    
    shared variable Tree.Declaration? declaration = null;
    variable Tree.Declaration? current = null;
    
    shared actual void visit(Tree.Declaration that) {
        Tree.Declaration? myOuter = current;
        current = that;
        super.visit(that);
        current = myOuter;
    }
    
    shared actual void visitAny(Node node) {
        if (node == term) {
            declaration = current;
        }
        
        if (!declaration exists) {
            super.visitAny(node);
        }
    }
}