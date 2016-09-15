import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node
}
import com.redhat.ceylon.model.typechecker.model {
    Scope
}
class FindInvocationVisitor(Node node) extends Visitor() {
    shared variable Tree.InvocationExpression? result = null;
    
    shared actual void visit(Tree.InvocationExpression that) {
        if (exists pal = that.positionalArgumentList, pal==node) {
            result = that;
        }
        if (exists nal = that.namedArgumentList, nal==node) {
            result = that;
        }
        super.visit(that);
    }

}


class FindInvocationVisitor2(Scope scope) extends Visitor() {
    shared variable Tree.InvocationExpression? result = null;

    shared actual void visit(Tree.InvocationExpression that) {
        if (exists pal = that.positionalArgumentList, pal.scope==scope) {
            result = that;
        }
        if (exists nal = that.namedArgumentList, nal.scope==scope) {
            result = that;
        }
        super.visit(that);
    }

}
