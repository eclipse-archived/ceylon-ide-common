import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node
}
class FindInvocationVisitor(Node node) extends Visitor() {
    shared variable Tree.InvocationExpression? result = null;
    
    shared actual void visit(Tree.InvocationExpression that) {
        if (that.namedArgumentList==node ||
                    that.positionalArgumentList==node) {
            result = that;
        }
        super.visit(that);
    }
}
