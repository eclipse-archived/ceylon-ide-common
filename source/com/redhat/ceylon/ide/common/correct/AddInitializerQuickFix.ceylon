import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue,
    TypedDeclaration
}

shared interface AddInitializerQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TypedDeclaration dec, 
        Integer offset, Integer length, TextChange change);
    
    shared void addInitializerProposals(Data data, IFile file) {
        value node = data.node;
        
        if (is Tree.AttributeDeclaration node) {
            value attDecNode = node;
            Tree.SpecifierOrInitializerExpression? sie = attDecNode.specifierOrInitializerExpression;
            
            if (!(sie is Tree.LazySpecifierExpression)) {
                addInitializerProposal(data, file, attDecNode);
            }
        }
        
        if (is Tree.MethodDeclaration node) {
            value methDecNode = node;
            addInitializerProposal(data, file, methDecNode);
        }
    }

    void addInitializerProposal(Data data, IFile file, 
        Tree.TypedDeclaration decNode) {
        
        assert (is FunctionOrValue? dec = decNode.declarationModel);
        if (!exists dec) {
            return;
        }
        
        if (!dec.initializerParameter exists, !dec.formal) {
            value change = newTextChange("Add Initializer", file);
            value offset = decNode.endIndex.intValue() - 1;
            value defaultValue = correctionUtil.defaultValue(data.rootNode.unit, dec.type);
            
            String def;
            Integer selectionOffset;
            if (is Tree.MethodDeclaration decNode) {
                def = " => " + defaultValue;
                selectionOffset = offset + 4;
            } else {
                def = " = " + defaultValue;
                selectionOffset = offset + 3;
            }
            
            addEditToChange(change, newInsertEdit(offset, def));
            
            value desc = "Add initializer to '``dec.name``'";
            newProposal(data, desc, dec, selectionOffset, defaultValue.size, change);
        }
    }

}