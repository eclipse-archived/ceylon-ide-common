import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import java.util {
    List
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.ide.common.util {
    NodePrinter
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}

shared interface AbstractRefactoring<RefactoringData> satisfies Refactoring & NodePrinter {
    shared interface EditorData {
        shared formal List<CommonToken>? tokens;
        shared formal Tree.CompilationUnit? rootNode;
        shared formal Node? node;
        shared formal VirtualFile? sourceVirtualFile;
    }

    shared formal EditorData? editorData;

    shared formal Boolean editable;

    shared Tree.Term unparenthesize(Tree.Term term) {
        if (is Tree.Expression term, !is Tree.Tuple t = term.term) {
            return unparenthesize(term.term);
        }
        return term;
    }

    shared formal List<PhasedUnit> getAllUnits();
    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Tree.CompilationUnit? rootNode;

    shared default Integer countDeclarationOccurrences() {
        variable Integer count = 0;
        for (pu in CeylonIterable(getAllUnits())) {
            if (searchInFile(pu)) {
                count += countReferences(pu.compilationUnit);
            }
        }
        if (searchInEditor(), exists existingRoot=rootNode) {
            count += countReferences(existingRoot);
        }
        return count;
    }

    shared default Integer countReferences(Tree.CompilationUnit cu) => 0;

    shared formal Anything build(RefactoringData refactoringData);
}