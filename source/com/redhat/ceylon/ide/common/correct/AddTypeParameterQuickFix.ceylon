import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared object addTypeParameterQuickFix {
    
    shared void addTypeParameterProposal(QuickFixData data) {
        assert (is Tree.TypeConstraint tcn = data.node);
        value tp = tcn.declarationModel;
        assert (is Tree.Declaration decNode 
            = nodes.getReferencedNodeInUnit {
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
                = platformServices.createTextChange {
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
            desc = "Add '``tp.name``' to type parameter list of '``decNode.declarationModel.name``'";
            change = change;
        };
    }
}
