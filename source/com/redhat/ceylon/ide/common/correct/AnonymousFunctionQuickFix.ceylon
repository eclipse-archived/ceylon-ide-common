import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}

shared interface AnonymousFunctionQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal ConvertToBlockQuickFix<IFile,IDocument,InsertEdit,TextEdit,
    TextChange,Region,Project,Data,CompletionResult> convertToBlockQuickFix;
    
    shared formal ConvertToSpecifierQuickFix<IFile,IDocument,InsertEdit,TextEdit,
    TextChange,Region,Project,Data,CompletionResult> convertToSpecifierQuickFix;

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
}
