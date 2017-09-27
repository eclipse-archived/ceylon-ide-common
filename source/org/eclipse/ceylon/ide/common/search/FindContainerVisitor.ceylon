import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import java.lang {
    overloaded
}

shared class FindContainerVisitor(Node node) extends Visitor() {
    variable Tree.StatementOrArgument? declaration = null;
    variable Tree.StatementOrArgument? currentDeclaration = null;
    
    shared Tree.StatementOrArgument? statementOrArgument 
            => declaration;
    
    shared default Boolean accept(Tree.StatementOrArgument node) => true;

    overloaded
    shared actual void visit(Tree.ImportModule that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.Import that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.ModuleDescriptor that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.PackageDescriptor that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyAttribute that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyMethod that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyClass that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AnyInterface that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.TypeAliasDeclaration that) {
        value d = currentDeclaration;
        if (accept(that)) {
            currentDeclaration = that;
        }
        
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visitAny(Node node) {
        if (this.node == node) {
            declaration = currentDeclaration;
        }
        
        if (!exists _ = declaration) {
            super.visitAny(node);
        }
    }
}
