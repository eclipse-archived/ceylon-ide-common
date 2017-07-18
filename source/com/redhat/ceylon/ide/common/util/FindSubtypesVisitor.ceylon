import ceylon.collection {
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    TypeDeclaration
}

import java.util {
    JSet = Set
}
import ceylon.interop.java {
    JavaSet
}
import java.lang {
    overloaded
}

shared class FindSubtypesVisitor(TypeDeclaration declaration) extends Visitor() {
    value nodes = HashSet<Tree.Declaration|Tree.ObjectExpression>();
    
    shared Set<Tree.Declaration|Tree.ObjectExpression> declarationNodes => nodes;
    shared JSet<Tree.Declaration|Tree.ObjectExpression> declarationNodeSet => JavaSet(nodes);
    
    Boolean isRefinement(TypeDeclaration? dec) 
            => dec?.inherits(declaration) else false;

    overloaded
    shared actual void visit(Tree.TypeDeclaration that) {
        if (isRefinement(that.declarationModel)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        if (isRefinement(that.declarationModel.typeDeclaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ObjectExpression that) {
        if (exists t=that.typeModel, isRefinement(t.declaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
}
