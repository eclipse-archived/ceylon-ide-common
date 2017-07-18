import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Setter
}
import ceylon.collection {
    HashSet
}
import java.util {
    JSet=Set
}
import ceylon.interop.java {
    JavaSet
}
import java.lang {
    overloaded
}

shared class FindRefinementsVisitor(Declaration declaration) extends Visitor() {

    value nodes = HashSet<Tree.StatementOrArgument>();
    
    shared Set<Tree.StatementOrArgument> declarationNodes => nodes; 
    shared JSet<Tree.StatementOrArgument> declarationNodeSet => JavaSet(nodes);
    
    Boolean isRefinement(Declaration? dec) {
        return if (exists dec) 
               then dec.refines(declaration) || isSetterRefinement(dec)
               else false;
    }
    
    Boolean isSetterRefinement(Declaration dec) {
        if (is Setter dec) {
            return (dec).getter.refines(declaration);
        } else {
            return false;
        }
    }

    overloaded
    shared actual void visit(Tree.SpecifierStatement that) {
        if (that.refinement, isRefinement(that.declaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.Declaration that) {
        if (!(that is Tree.TypeConstraint), isRefinement(that.declarationModel)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
}
