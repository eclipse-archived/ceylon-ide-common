import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import java.util {
    List
}
import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.settings {
    CompletionOptions
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument
}

"The result of the local typechecking of a CompilationUnit.
 For example, this can be used when a file is being modified,
 but the resulting PhasedUnit should not be added to the global model."
shared interface LocalAnalysisResult<Document> {
    shared formal Tree.CompilationUnit lastCompilationUnit;
    shared formal Tree.CompilationUnit parsedRootNode;
    shared formal Tree.CompilationUnit? typecheckedRootNode;
    shared formal PhasedUnit lastPhasedUnit;
    shared formal Document document;
    shared formal CommonDocument commonDocument;
    shared formal List<CommonToken>? tokens;
    shared formal TypeChecker typeChecker;
    shared formal BaseCeylonProject? ceylonProject;
    shared formal CompletionOptions options;
}