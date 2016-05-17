import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.imports {
    moduleImportUtil
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Declaration
}

shared object exportModuleImportQuickFix {

    shared void applyChanges(QuickFixData data, Unit u, String moduleName) {
        moduleImportUtil.exportModuleImports(data, u.\ipackage.\imodule, moduleName);
    }
    
    shared void addExportModuleImportProposal(QuickFixData data) {
        if (is Tree.SimpleType node = data.node) {
            value dec = (node).declarationModel;
            addExportModuleImportProposalInternal(data, node.unit, dec);
        }
    }

    shared void addExportModuleImportProposalForSupertypes(QuickFixData data) {
        variable Node? node = data.node;
        value unit = data.node.unit;
        value rootNode = data.rootNode;
        
        if (is Tree.InitializerParameter n = node) {
            node = nodes.getReferencedNodeInUnit(nodes.getReferencedModel(n), rootNode);
        }
        
        if (is Tree.TypedDeclaration n = node) {
            node = n.type;
        }
        
        if (is Tree.ClassOrInterface c = node) {
            if (exists extendedType = c.declarationModel.extendedType) {
                addExportModuleImportProposalInternal(data, unit, extendedType.declaration);
                for (typeArgument in extendedType.typeArgumentList) {
                    addExportModuleImportProposalInternal(data, unit, typeArgument.declaration);
                }
            }
            
            if (exists satisfiedTypes = c.declarationModel.satisfiedTypes) {
                for (satisfiedType in satisfiedTypes) {
                    addExportModuleImportProposalInternal(data, unit, satisfiedType.declaration);
                    for (typeArgument in satisfiedType.typeArgumentList) {
                        addExportModuleImportProposalInternal(data, unit, typeArgument.declaration);
                    }
                }
            }
        } else if (is Tree.Type n = node) {
            value type = n.typeModel;
            addExportModuleImportProposalInternal(data, unit, type.declaration);
            for (typeArgument in type.typeArgumentList) {
                addExportModuleImportProposalInternal(data, unit, typeArgument.declaration);
            }
        }
    }

    void addExportModuleImportProposalInternal(QuickFixData data, Unit unit, Declaration dec) {
        
        value decModule = dec.unit.\ipackage.\imodule;
        for (mi in unit.\ipackage.\imodule.imports) {
            if (mi.\imodule.equals(decModule)) {
                if (mi.export) {
                    return;
                }
            }
        }
        
        value desc = "Export 'import " + decModule.nameAsString + " \"" 
                + decModule.version + "\"' to clients of module";

        data.addExportModuleImportProposal(unit, desc, 
            decModule.nameAsString, decModule.version);
    }

}
