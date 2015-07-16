import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    NaturalVisitor,
    Node,
    Tree
}

class FindStatementVisitor(Node term, Boolean toplevel) extends Visitor() satisfies NaturalVisitor {
    
    variable Boolean inParameter = false;
    variable Boolean currentlyToplevel = true;
    variable Boolean resultIsToplevel = false;
    shared variable Tree.Statement? statement = null;
    variable Tree.Statement? currentStatement = null;

    shared actual void visit(Tree.Parameter that) {
        Boolean tmp = inParameter;
        inParameter = true;
        super.visit(that);
        inParameter = tmp; 
    }
    
    shared actual void visit(Tree.Statement that) {
        if ((!toplevel || currentlyToplevel) && !inParameter) {
            if (that is Tree.Variable || that is Tree.TypeConstraint || that is Tree.TypeParameterDeclaration) {
                currentStatement = that;
                resultIsToplevel = currentlyToplevel;
            }
        }
        
        Boolean tmp = currentlyToplevel;
        currentlyToplevel = false;
        super.visit(that);
        currentlyToplevel = tmp;
    }
    
    shared actual void visitAny(Node node) {
        if (node == term) {
            statement = currentStatement;
            resultIsToplevel = currentlyToplevel;
        }
        
        if (!exists s = statement) {
            super.visitAny(node);
        }
    }
}