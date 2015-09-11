import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    createJavaObjectArray
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}

import java.lang {
    ObjectArray
}

shared class FindContainingExpressionsVisitor(Integer offset) extends Visitor() {

    ArrayList<Tree.Term> myElements = ArrayList<Tree.Term>();
    
    shared ObjectArray<Tree.Term> elements => createJavaObjectArray(myElements);
    
    shared actual void visit(Tree.Term that) {
        super.visit(that);
        
        if (!is Tree.Expression that,
                exists start = that.startIndex?.intValue(),
                exists end = that.endIndex?.intValue(),
                start <= offset && end >= offset) {
            myElements.add(that);
        }
    }
}