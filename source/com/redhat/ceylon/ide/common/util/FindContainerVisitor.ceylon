import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import java.lang {
    overloaded
}

shared class FindContainerVisitor(Node node) extends Visitor() {
    
    shared variable Tree.Declaration? declaration = null;
    variable Tree.Declaration? currentDeclaration = null;

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyAttribute that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyMethod that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.Constructor that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.ClassDefinition that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.InterfaceDefinition that) {
        value d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visitAny(Node node) {
        if (this.node == node) {
            declaration = currentDeclaration;
        }
        if (!exists d = declaration) {
            super.visitAny(node);
        }
    }
}
