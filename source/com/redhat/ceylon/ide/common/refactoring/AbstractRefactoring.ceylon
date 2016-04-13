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
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Declaration
}

Boolean descriptor(VirtualFile sourceFile) 
        => sourceFile.name == "module.ceylon" ||
        sourceFile.name == "package.ceylon";

Boolean editable(Unit? unit)
        => unit is EditedSourceFile<in Nothing, in Nothing, in Nothing, in Nothing> |
                   ProjectSourceFile<in Nothing, in Nothing, in Nothing, in Nothing>;

shared interface AbstractRefactoring<RefactoringData> 
        satisfies Refactoring {
    
    shared interface EditorData {
        shared formal List<CommonToken> tokens;
        shared formal Tree.CompilationUnit rootNode;
        shared formal Node node;
        shared formal VirtualFile? sourceVirtualFile;
    }

    shared formal EditorData editorData;

    shared formal List<PhasedUnit> getAllUnits();
    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Boolean inSameProject(Declaration decl);
    shared default Tree.CompilationUnit rootNode => editorData.rootNode;

    shared Tree.Term unparenthesize(Tree.Term term) {
        if (is Tree.Expression term, !is Tree.Tuple t = term.term) {
            return unparenthesize(term.term);
        }
        return term;
    }
    
    shared formal Boolean visibleOutsideUnit;
    
    shared default Integer countDeclarationOccurrences() {
        variable Integer count = 0;
        if (visibleOutsideUnit) {
            for (pu in getAllUnits()) {
                if (searchInFile(pu)) {
                    count += countReferences(pu.compilationUnit);
                }
            }
        }
        if (searchInEditor()) {
            count += countReferences(rootNode);
        }
        return count;
    }

    shared default Integer countReferences(Tree.CompilationUnit cu) => 0;

    shared formal Anything build(RefactoringData refactoringData);
}