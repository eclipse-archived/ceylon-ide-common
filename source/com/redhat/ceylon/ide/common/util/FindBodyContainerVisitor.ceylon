import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}

class FindBodyContainerVisitor(Node node) extends Visitor() {
    
    shared variable Tree.Declaration? declaration = null;
    variable Tree.Declaration? currentDeclaration = null;
    
    shared actual void visit(Tree.ObjectDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.AttributeGetterDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.MethodDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.Constructor that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.ClassDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visit(Tree.InterfaceDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visitAny(Node node) {
        if (this.node==node) {
            declaration=currentDeclaration;
        }
        if (!exists d = declaration) {
            super.visitAny(node);
        }
    }
}