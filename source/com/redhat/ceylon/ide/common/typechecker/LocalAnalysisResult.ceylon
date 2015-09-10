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
    CeylonProject
}
"The result of the local typechecking of a CompilationUnit.
 For example, this can be used when a file is being modified,
 but the resulting PhasedUnit should not be added to the global model."
shared interface LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    shared formal Tree.CompilationUnit rootNode;
    shared formal PhasedUnit phasedUnit;
    shared formal Document document;
    shared formal List<CommonToken>? tokens;
    shared formal TypeChecker typeChecker;
    shared formal CeylonProject<IdeArtifact>? ceylonProject;
}