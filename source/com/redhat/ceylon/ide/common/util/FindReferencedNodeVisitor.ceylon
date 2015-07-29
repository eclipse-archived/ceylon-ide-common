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
        if (exists dec, is Declaration declaration, dec.equals(declaration)) {
            if (dec.native, !dec.nativeBackend.equals(declaration.nativeBackend)) {
                return false;
            }
            
            if (is Function declaration, declaration.overloaded) {
                return declaration == dec;
            }
            return true;
        } else {
            return false;
        }
    }
    
    actual shared void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        Referenceable? m = that.importPath.model;
        if (exists m, exists declaration, m.equals(declaration)) {
            declarationNode = that;
        }
    }
    
    actual shared void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        Referenceable? p = that.importPath.model;
        if (exists p, exists declaration, p.equals(declaration)) {
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
        value setter = that.declarationModel;
        if (isDeclaration(setter.getDirectMember(setter.name, null, false))) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visit(Tree.ObjectDefinition that) {
        if (isDeclaration(that.declarationModel.typeDeclaration)) {
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
        if (isDeclaration(that.parameterModel.model)) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    actual shared void visitAny(Node node) {
        if (declarationNode is Null ||
            declarationNode is Tree.InitializerParameter) {
            super.visitAny(node);
        }
    }

}