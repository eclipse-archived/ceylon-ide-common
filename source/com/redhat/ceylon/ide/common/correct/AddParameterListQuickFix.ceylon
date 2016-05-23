import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared object addParameterListQuickFix {
    
    shared void addParameterListProposal(QuickFixData data, Boolean evenIfEmpty) {
        value node 
                = if (is Tree.TypedDeclaration node = data.node)
                then nodes.findDeclarationWithBody(data.rootNode, node) 
                else data.node;
        
        if (is Tree.ClassDefinition node, 
            !node.parameterList exists) {
            
            value uninitialized = 
                    correctionUtil.collectUninitializedMembers(node.classBody);
            if (evenIfEmpty || !uninitialized.empty) {
                value params = StringBuilder().append("(");
                for (ud in uninitialized) {
                    if (params.size > 1) {
                        params.append(", ");
                    }                        
                    params.append(ud.name);
                }
                
                params.append(")");
                value change 
                        = platformServices.document.createTextChange {
                    name = "Add Parameter List";
                    input = data.phasedUnit;
                };
                value offset 
                        = correctionUtil.getBeforeParenthesisNode(node)
                            .endIndex
                            .intValue();
                change.addEdit(InsertEdit {
                    start = offset;
                    text = params.string;
                });
                
                value description = correctionUtil.getDescription(node.declarationModel);
                data.addQuickFix {
                    description = "Add initializer parameters '``params``' to ``description``";
                    change = change;
                    selection = DefaultRegion(offset + 1);
                    kind = addParameterList;
                };
            }
        }
    }

    
}