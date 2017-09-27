import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}

shared object addTypeParameterQuickFix {
    
    shared void addTypeParameterProposal(QuickFixData data) {
        assert (is Tree.TypeConstraint tcn = data.node);
        value tp = tcn.declarationModel;
        assert (is Tree.Declaration decNode 
            = nodes.getReferencedNode {
                model = tp.declaration;
                rootNode = data.rootNode;
            });
        
        Tree.TypeParameterList? tpl;
        switch (decNode)
        case (is Tree.ClassOrInterface) {
            tpl = decNode.typeParameterList;
        }
        case (is Tree.AnyMethod) {
            tpl = decNode.typeParameterList;
        }
        case (is Tree.TypeAliasDeclaration) {
            tpl = decNode.typeParameterList;
        } else {
            return;
        }
        
        value change 
                = platformServices.document.createTextChange {
            name = "Add Type Parameter";
            input = data.phasedUnit;
        };
        InsertEdit edit;
        if (!exists tpl) {
            value id = decNode.identifier;
            edit = InsertEdit {
                start = id.endIndex.intValue();
                text = "<" + tp.name + ">";
            };
        }
        else {
            edit = InsertEdit {
                start = tpl.endIndex.intValue() - 1;
                text = ", " + tp.name;
            };
        }
        
        change.addEdit(edit);
        
        data.addQuickFix {
            description = "Add '``tp.name``' to type parameter list of '``decNode.declarationModel.name``'";
            change = change;
            affectsOtherUnits = true;
        };
    }
}
