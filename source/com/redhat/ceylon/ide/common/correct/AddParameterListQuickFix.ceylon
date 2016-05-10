import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
shared interface AddParameterListQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, Integer start, 
        String desc, TextChange change);
    
    shared void addParameterListProposal(Data data, IFile file, Boolean evenIfEmpty) {
        variable Node? node = data.node;
        
        if (is Tree.TypedDeclaration n = node) {
            node = nodes.findDeclarationWithBody(data.rootNode, n);
        }
        
        if (is Tree.ClassDefinition decNode = node) {
            value n = correctionUtil.getBeforeParenthesisNode(decNode);
            
            if (!decNode.parameterList exists) {
                value dec = decNode.declarationModel;
                value uninitialized = 
                        correctionUtil.collectUninitializedMembers(decNode.classBody);
                
                if (evenIfEmpty || !uninitialized.empty) {
                    value params = StringBuilder().append("(");
                    for (ud in uninitialized) {
                        if (params.size > 1) {
                            params.append(", ");
                        }
                        
                        params.append(ud.name);
                    }
                    
                    params.append(")");
                    value change = newTextChange("Add Parameter List", file);
                    value offset = n.endIndex.intValue();
                    addEditToChange(change, newInsertEdit(offset, params.string));
                    
                    newProposal(data, offset + 1, 
                        "Add initializer parameters '" + params.string + "' to "
                                + correctionUtil.getDescription(dec), change);
                }
            }
        }
    }

    
}