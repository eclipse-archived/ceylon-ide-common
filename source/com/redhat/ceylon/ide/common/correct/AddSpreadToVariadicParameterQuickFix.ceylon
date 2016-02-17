import com.redhat.ceylon.model.typechecker.model {
    TypedDeclaration,
    FunctionOrValue
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface AddSpreadToVariadicParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, 
        TypedDeclaration parameter, Integer offset, TextChange change); 
    
    shared void addSpreadToSequenceParameterProposal(Data data, IFile file) {
        if (is Tree.Term term = data.node) {
            value type = term.typeModel;
            value id = type.declaration.unit.iterableDeclaration;
            if (!type.getSupertype(id) exists) {
                return;
            }
            
            value fiv = FindInvocationVisitor(term);
            fiv.visit(data.rootNode);
            
            value param = fiv.parameter;
            if (exists param,
                param.parameter,
                is FunctionOrValue param,
                param.initializerParameter.sequenced) {

                value change = newTextChange("Spread iterable argument of variadic parameter", file);
                addEditToChange(change, newInsertEdit(term.startIndex.intValue(), "*"));
                
                newProposal(data, "Spread iterable argument of variadic parameter",
                    param, term.endIndex.intValue() + 3, change);
            }
        }
    }
}
