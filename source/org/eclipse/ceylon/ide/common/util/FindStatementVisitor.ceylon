import org.eclipse.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import java.lang {
    overloaded
}

class FindStatementVisitor(Node term, Boolean toplevel) extends Visitor() {
    
    variable Boolean inParameter = false;
    variable Boolean currentlyToplevel = true;
    variable Boolean resultIsToplevel = false;
    shared variable Tree.Statement? statement = null;
    variable Tree.Statement? currentStatement = null;

    overloaded
    shared actual void visit(Tree.Parameter that) {
        Boolean tmp = inParameter;
        inParameter = true;
        super.visit(that);
        inParameter = tmp; 
    }

    overloaded
    shared actual void visit(Tree.IfStatement that) {
        if (!toplevel) {
            currentStatement = that;
        }
        that.ifClause?.visit(this);
        if (!toplevel) {
            currentStatement = that;
        }
        that.elseClause?.visit(this);
    }

    overloaded
    shared actual void visit(Tree.ForStatement that) {
        if (!toplevel) {
            currentStatement = that;
        }
        that.forClause?.visit(this);
        if (!toplevel) {
            currentStatement = that;
        }
        that.elseClause?.visit(this);
    }
    
    //TODO: same thing for SwitchStatement and TryStatement!!

    overloaded
    shared actual void visit(Tree.Statement that) {
        if ((!toplevel || currentlyToplevel) && !inParameter) {
            if (! (that is Tree.Variable ||
                    that is Tree.TypeConstraint ||
                    that is Tree.TypeParameterDeclaration)) {
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
        if (node === term) {
            statement = currentStatement;
            resultIsToplevel = currentlyToplevel;
        }

        if (! statement exists) {
            super.visitAny(node);
        }
    }
}