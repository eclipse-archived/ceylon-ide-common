import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import java.util {
    List
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.ide.common.util {
    NodePrinter
}

shared interface CommonRefactoring satisfies NodePrinter {

    Tree.Term unparenthesize(Tree.Term term) {
        if (is Tree.Expression term, !is Tree.Tuple t = term.term) {
            return unparenthesize(term.term);
        }
        return term;
    }
    
    shared formal List<PhasedUnit> getAllUnits();
    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Tree.CompilationUnit rootNode;
    
    shared default Integer countDeclarationOccurrences() {
        variable Integer count = 0;
        for (pu in CeylonIterable(getAllUnits())) {
            if (searchInFile(pu)) {
                count += countReferences(pu.compilationUnit);
            }
        }
        if (searchInEditor()) {
            count += countReferences(rootNode);
        }
        return count;
    }
    
    shared default Integer countReferences(Tree.CompilationUnit cu) {
        return 0;
    }

    shared actual default String toString(Node node) => node.text;
}