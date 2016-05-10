import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

shared interface SpecifyTypeArgumentsQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addSpecifyTypeArgumentsProposal(Tree.MemberOrTypeExpression ref, 
        Data data, IFile file) {
        
        Tree.Identifier identifier;
        Tree.TypeArguments typeArguments;
        
        if (is Tree.BaseMemberOrTypeExpression ref) {
            identifier = (ref).identifier;
            typeArguments = (ref).typeArguments;
        } else if (is Tree.QualifiedMemberOrTypeExpression ref) {
            identifier = (ref).identifier;
            typeArguments = (ref).typeArguments;
        } else {
            return;
        }
        
        if (typeArguments is Tree.InferredTypeArguments, typeArguments.typeModels exists, !typeArguments.typeModels.empty) {
            value builder = StringBuilder().append("<");
            for (arg in typeArguments.typeModels) {
                if (ModelUtil.isTypeUnknown(arg)) {
                    return;
                }
                
                if (builder.size != 1) {
                    builder.append(",");
                }
                
                builder.append(arg.asSourceCodeString(data.node.unit));
            }
            
            builder.append(">");
            value change = newTextChange("Specify Explicit Type Arguments", file);
            addEditToChange(change, newInsertEdit(identifier.endIndex.intValue(), builder.string));
            
            String desc = "Specify explicit type arguments '" + builder.string + "'";
            newProposal(data, desc, change);
        }
    }
}
