import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil,
    Declaration
}
import java.util {
    HashSet
}

shared interface VerboseRefinementQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addVerboseRefinementProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.SpecifierStatement ss = statement,
            ss.refinement) {

            value change = newTextChange("Convert to Verbose Refinement", file);
            initMultiEditChange(change);

            if (exists e = ss.specifierExpression.expression,
                !ModelUtil.isTypeUnknown(e.typeModel)) {
                
                value unit = ss.unit;
                value t = unit.denotableType(e.typeModel);
                value decs = HashSet<Declaration>();
                importProposals.importType(decs, t, data.rootNode);
                importProposals.applyImports(change, decs, data.rootNode, getDocumentForChange(change));
                value type = t.asSourceCodeString(unit);
                
                addEditToChange(change, newInsertEdit(ss.startIndex.intValue(), "shared actual " + type + " "));
                
                newProposal(data, "Convert to verbose refinement", change);
            }
        }
    }

    shared void addNonVerboseRefinementProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.AttributeDeclaration attr = statement,
            is Tree.SpecifierExpression spec = attr.specifierOrInitializerExpression,
            exists model = attr.declarationModel,
            model.actual) {
            
            value change = newTextChange("Convert to non-verbose Refinement", file);
            initMultiEditChange(change);
            
            if (exists e = spec.expression,
                !ModelUtil.isTypeUnknown(e.typeModel)) {
                
                value start = attr.startIndex.intValue();
                value length = attr.identifier.startIndex.intValue() - start;
                addEditToChange(change, newDeleteEdit(start, length));
                
                newProposal(data, "Convert to non-verbose refinement", change);
            }
        }
    }
}