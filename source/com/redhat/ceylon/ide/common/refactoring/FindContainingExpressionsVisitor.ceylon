import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import ceylon.collection {
    ArrayList
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import java.lang {
    ObjectArray
}
import ceylon.interop.java {
    createJavaObjectArray
}

shared class FindContainingExpressionsVisitor(Integer offset) extends Visitor() {

    ArrayList<Tree.Term> myElements = ArrayList<Tree.Term>();
    
    shared ObjectArray<Tree.Term> elements => createJavaObjectArray(myElements);
    
    shared actual void visit(Tree.Term that) {
        super.visit(that);
        
        if (!is Tree.Expression that, nodes.getNodeStartOffset(that) <= offset,
                nodes.getNodeEndOffset(that) + 1 >= offset) {
            myElements.add(that);
        }
    }
}