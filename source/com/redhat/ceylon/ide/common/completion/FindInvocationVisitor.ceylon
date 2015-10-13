import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node
}
class FindInvocationVisitor(Node node) extends Visitor() {
    shared variable Tree.InvocationExpression? result = null;
    
    shared actual void visit(Tree.InvocationExpression that) {
        if (eq(that.namedArgumentList, node)
            || eq(that.positionalArgumentList, node)) {
            result = that;
        }
        super.visit(that);
    }
    
    Boolean eq(Node? a, Node b) {
        return if (exists a) then a == b else false;
    }
}
