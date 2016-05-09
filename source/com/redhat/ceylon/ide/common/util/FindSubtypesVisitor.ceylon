import java.util {
    HashSet,
    Set
}
import com.redhat.ceylon.model.typechecker.model {
    TypeDeclaration
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}

shared class FindSubtypesVisitor(TypeDeclaration declaration) extends Visitor() {
    shared Set<Tree.Declaration|Tree.ObjectExpression> declarationNodes
            = HashSet<Tree.Declaration|Tree.ObjectExpression>();
    
    Boolean isRefinement(TypeDeclaration? dec) 
            => dec?.inherits(declaration) else false;
    
    shared actual void visit(Tree.TypeDeclaration that) {
        if (isRefinement(that.declarationModel)) {
            declarationNodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ObjectDefinition that) {
        if (isRefinement(that.declarationModel.typeDeclaration)) {
            declarationNodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ObjectExpression that) {
        if (exists t=that.typeModel, isRefinement(t.declaration)) {
            declarationNodes.add(that);
        }
        
        super.visit(that);
    }
}
