import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    Function
}
import java.lang {
    overloaded
}

shared class FindReferencedNodeVisitor(Referenceable? declaration) extends Visitor() {
    
    shared variable Node? declarationNode = null;
    
    Boolean isDeclaration(Declaration? dec) {
        if (exists dec, exists declaration, dec==declaration) {
            if (is Declaration declaration, 
                declaration.native && dec.native, 
                dec.nativeBackends != declaration.nativeBackends) {
                return false;
            }
            else if (is Function declaration) {
                return !declaration.overloaded
                    || declaration === dec;
            }
            else {
                return true;
            }
        }
        else {
            return false;
        }
    }

    overloaded
    actual shared void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        Referenceable? m = that.importPath.model;
        if (exists m, exists declaration, m==declaration) {
            declarationNode = that;
        }
    }

    overloaded
    actual shared void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        Referenceable? p = that.importPath.model;
        if (exists p, exists declaration, p==declaration) {
            declarationNode = that;
        }
    }

    overloaded
    actual shared void visit(Tree.Declaration that) {
        if (isDeclaration(that.declarationModel)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.Constructor that) {
        if (isDeclaration(that.constructor)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.Enumerated that) {
        if (isDeclaration(that.enumerated)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.AttributeSetterDefinition that) {
        if (isDeclaration(that.declarationModel?.parameter?.model)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.ObjectDefinition that) {
        if (isDeclaration(that.anonymousClass)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.ObjectExpression that) {
        if (isDeclaration(that.anonymousClass)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.SpecifierStatement that) {
        if (that.refinement) {
            if (isDeclaration(that.declaration)) {
                declarationNode = that;
            }
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.FunctionArgument that) {
        if (isDeclaration(that.declarationModel)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    actual shared void visit(Tree.InitializerParameter that) {
        if (isDeclaration(that.parameterModel?.model)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visitAny(Node node) {
        if (declarationNode is Tree.InitializerParameter?) {
            super.visitAny(node);
        }
    }

}