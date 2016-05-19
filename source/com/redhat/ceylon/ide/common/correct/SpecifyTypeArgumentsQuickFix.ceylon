import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}

shared object specifyTypeArgumentsQuickFix {
    
    shared void addSpecifyTypeArgumentsProposal(
        Tree.MemberOrTypeExpression ref, 
        QuickFixData data) {
        
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
        
        if (typeArguments is Tree.InferredTypeArguments, 
            typeArguments.typeModels exists, 
            !typeArguments.typeModels.empty) {
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
            value change = platformServices.createTextChange {
                name = "Specify Explicit Type Arguments";
                input = data.phasedUnit;
            };
            change.addEdit( 
                InsertEdit {
                    start = identifier.endIndex.intValue();
                    text = builder.string;
                });
            data.addQuickFix("Specify explicit type arguments '``builder``'", change);
        }
    }
}
