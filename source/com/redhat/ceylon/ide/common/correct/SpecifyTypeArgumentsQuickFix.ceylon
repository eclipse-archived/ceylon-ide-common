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

        switch (ref)
        case (is Tree.BaseMemberOrTypeExpression) {
            identifier = ref.identifier;
            typeArguments = ref.typeArguments;
        }
        case (is Tree.QualifiedMemberOrTypeExpression) {
            identifier = ref.identifier;
            typeArguments = ref.typeArguments;
        }
        else {
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
            value change = platformServices.document.createTextChange {
                name = "Specify Explicit Type Arguments";
                input = data.phasedUnit;
            };
            change.addEdit( 
                InsertEdit {
                    start = identifier.endIndex.intValue();
                    text = builder.string;
                });
            data.addQuickFix {
                description = "Specify explicit type arguments '``builder``'";
                change = change;
            };
        }
    }

    shared void addTypingProposals(QuickFixData data) {
        if (is Tree.MemberOrTypeExpression node = data.node) {
            specifyTypeArgumentsQuickFix.addSpecifyTypeArgumentsProposal(node, data);
        }
    }
    
}
