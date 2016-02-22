import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}

// TODO rename to something like BlockQuickFix?
shared interface MiscQuickFixes<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal ConvertToBlockQuickFix<IFile,IDocument,InsertEdit,TextEdit,
    TextChange,Region,Project,Data,CompletionResult> convertToBlockQuickFix;
    
    shared formal ConvertToSpecifierQuickFix<IFile,IDocument,InsertEdit,TextEdit,
    TextChange,Region,Project,Data,CompletionResult> convertToSpecifierQuickFix;
    
    shared formal ConvertToGetterQuickFix<IFile,IDocument,InsertEdit,TextEdit,
    TextChange,Region,Project,Data,CompletionResult> convertToGetterQuickFix;

    shared void addAnonymousFunctionProposals(Data data, IFile file) {
        variable value currentOffset = data.node.startIndex.intValue();
        
        class FindAnonFunctionVisitor() extends Visitor() {
            variable shared Tree.FunctionArgument? result = null;
            
            shared actual void visit(Tree.FunctionArgument that) {
                if (currentOffset >= that.startIndex.intValue(),
                    currentOffset <= that.endIndex.intValue()) {
                    
                    result = that;
                }
                
                super.visit(that);
            }
        }
        
        value v = FindAnonFunctionVisitor();
        v.visit(data.rootNode);
        
        if (exists fun = v.result) {
            if (fun.expression exists) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, file, fun);
            }
            
            if (fun.block exists) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, file, fun.block, true);
            }
        }
    }

    shared void addDeclarationProposals(Data data, IFile file, Tree.Declaration? decNode, Integer currentOffset) {
        if (!exists decNode) {
            return;
        }
        
        if (exists al = decNode.annotationList,
            exists endIndex = al.endIndex?.intValue(),
            currentOffset <= endIndex) {
            
            return;
        }
        
        if (is Tree.TypedDeclaration tdn = decNode,
            exists type = tdn.type,
            exists endIndex = type.endIndex?.intValue(),
            currentOffset <= endIndex) {
            
            return;
        }
        
        switch (decNode)
        case(is Tree.AttributeDeclaration) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierOrInitializerExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, file, decNode);
            } else {
                convertToGetterQuickFix.addConvertToGetterProposal(data, file, decNode);
            }
        }
        case (is Tree.MethodDeclaration) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, file, decNode);
            }
        }
        case (is Tree.AttributeSetterDefinition) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, file, decNode);
            }
            
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, file, b);
            }
        }
        case (is Tree.AttributeGetterDefinition) {
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, file, b);
            }
        }
        case (is Tree.MethodDefinition) {
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, file, b);
            }
        }
        else {
        }
    }
}
