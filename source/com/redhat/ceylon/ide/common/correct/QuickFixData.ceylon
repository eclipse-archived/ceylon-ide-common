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
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Unit,
    Type,
    Referenceable,
    Scope
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
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
        QuickFixKind kind = generic);
    
    shared formal void addInitializerQuickFix(String description, TextChange change,
        DefaultRegion selection, Unit unit, Scope scope, Type? type);
    shared formal void addParameterQuickFix(String description, TextChange change,
        DefaultRegion selection, Unit unit, Scope scope, Type? type, Integer exitPos);
    shared formal void addModuleImportProposal(Unit u, String description,
        String name, String version);
    shared formal void addAnnotationProposal(Referenceable declaration, String text,
        String description, TextChange change, DefaultRegion? selection);
    shared formal void addChangeTypeProposal(String description, 
        TextChange change, DefaultRegion selection, Unit unit);
    shared formal void addConvertToClassProposal(String description,
        Tree.ObjectDefinition declaration);
    shared formal void addCreateParameterProposal(String description, Declaration dec,
        Type? type, DefaultRegion selection, Icons image, TextChange change, Integer exitPos);
    shared formal void addCreateQuickFix(String description,
        Scope scope, Unit unit, Type? returnType, Icons image,
        TextChange change, Integer exitPos, DefaultRegion selection);
    shared formal void addDeclareLocalProposal(String description,
        TextChange change, Tree.Term term, Tree.BaseMemberExpression bme);
    shared formal void addAssignToLocalProposal(String description);
    shared formal void addRefineFormalMembersProposal(String description);
    shared formal void addRefineEqualsHashProposal(String description, TextChange change);
}

abstract shared class QuickFixKind()
        of generic | addConstructor | addParameterList {
}
shared object addParameterList extends QuickFixKind() {}
shared object addConstructor extends QuickFixKind() {}
shared object generic extends QuickFixKind() {}
