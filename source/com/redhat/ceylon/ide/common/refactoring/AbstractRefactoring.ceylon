import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.model {
    EditedSourceFile,
    ProjectSourceFile
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}

shared interface AbstractRefactoring<RefactoringData> 
        satisfies Refactoring {
    
    shared interface EditorData {
        shared formal List<CommonToken> tokens;
        shared formal Tree.CompilationUnit rootNode;
        shared formal Node? node;
        shared formal VirtualFile? sourceVirtualFile;
    }

    shared formal EditorData? editorData;

    shared formal List<PhasedUnit> getAllUnits();
    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Tree.CompilationUnit? rootNode;

    shared Boolean editable 
            => let (unit = rootNode?.unit) 
            unit is EditedSourceFile<in Nothing, in Nothing, in Nothing, in Nothing> |
                    ProjectSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;
    
    shared Tree.Term unparenthesize(Tree.Term term) {
        if (is Tree.Expression term, !is Tree.Tuple t = term.term) {
            return unparenthesize(term.term);
        }
        return term;
    }
    
    shared default Integer countDeclarationOccurrences() {
        variable Integer count = 0;
        for (pu in getAllUnits()) {
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