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
            ss.refinement, 
            exists e = ss.specifierExpression.expression,
            !ModelUtil.isTypeUnknown(e.typeModel)) {
            
            value change = newTextChange("Convert to Verbose Refinement", file);
            initMultiEditChange(change);
            
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

    shared void addShortcutRefinementProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.TypedDeclaration statement,
            exists model = statement.declarationModel,
            model.actual, 
            exists spec = 
                    switch (statement) 
                    case (is Tree.AttributeDeclaration) 
                        statement.specifierOrInitializerExpression
                    case (is Tree.MethodDeclaration) 
                        statement.specifierExpression
                    else null,
            exists e = spec.expression,
            !ModelUtil.isTypeUnknown(e.typeModel)) {
            
            value change = newTextChange("Convert to Shortcut Refinement", file);
            initMultiEditChange(change);
            
            value start = statement.startIndex.intValue();
            value length = statement.identifier.startIndex.intValue() - start;
            addEditToChange(change, newDeleteEdit(start, length));
            
            newProposal(data, "Convert to shortcut refinement", change);
        }
    }
}