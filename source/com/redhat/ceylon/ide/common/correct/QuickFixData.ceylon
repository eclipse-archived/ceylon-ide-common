import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    TextChange
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

shared interface QuickFixData {
    shared formal Integer errorCode;
    shared formal Integer problemOffset;
    shared formal Integer problemLength;
    shared formal Node node;
    shared formal Tree.CompilationUnit rootNode;
    shared formal PhasedUnit phasedUnit;
    shared JList<CommonToken> tokens => phasedUnit.tokens;
    shared formal BaseCeylonProject ceylonProject;
    shared formal CommonDocument document;
    shared formal DefaultRegion editorSelection;
    "Set this flag to [[true]] to avoid heavy computations and delay them
     until the quick fix is called."
    shared default Boolean useLazyFixes => false;
    
    shared formal void addQuickFix(String description, TextChange|Callable<Anything, []> change,
        DefaultRegion? selection = null, 
        Boolean qualifiedNameIsPath = false,
        Icons? image = null,
        QuickFixKind kind = QuickFixKind.generic,
        String? hint = null,
        Boolean asynchronous = false,
        Declaration? declaration = null);
    
    shared formal void addConvertToClassProposal(String description,
        Tree.ObjectDefinition declaration);
    shared formal void addAssignToLocalProposal(String description);
}

shared class QuickFixKind
        of generic | addConstructor | addParameterList | addRefineEqualsHash
         | addRefineFormal | addModuleImport | addImport {
    shared new addImport {}
    shared new addModuleImport {}
    shared new addRefineFormal {}
    shared new addRefineEqualsHash {}
    shared new addParameterList {}
    shared new addConstructor {}
    shared new generic {}
}
