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
                return !declaration.overloaded ||
                        declaration === dec;
            }
            else {
                return true;
            }
        }
        else {
            return false;
        }
    }
    
    actual shared void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        if (exists m = that.importPath.model,
            exists declaration,
            declaration in m) {
            declarationNode = that;
        }
    }
    
    actual shared void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        if (exists p = that.importPath.model,
            exists declaration,
            declaration in p) {
            declarationNode = that;
        }
    }
    
    actual shared void visit(Tree.Declaration that) {
        if (isDeclaration(that.declarationModel)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.Constructor that) {
        if (isDeclaration(that.constructor)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.Enumerated that) {
        if (isDeclaration(that.enumerated)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.AttributeSetterDefinition that) {
        if (isDeclaration(that.declarationModel?.parameter?.model)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.ObjectDefinition that) {
        if (isDeclaration(that.anonymousClass)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.ObjectExpression that) {
        if (isDeclaration(that.anonymousClass)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.SpecifierStatement that) {
        if (that.refinement) {
            if (isDeclaration(that.declaration)) {
                declarationNode = that;
            }
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.FunctionArgument that) {
        if (isDeclaration(that.declarationModel)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
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