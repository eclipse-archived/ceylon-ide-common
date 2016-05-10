import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Declaration
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.ide.common.imports {
    AbstractModuleImportUtil
}

shared interface ExportModuleImportQuickFix<IFile, IDocument, InsertEdit, TextEdit, TextChange, Region, Project, Data, CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData {

    shared formal void newExportModuleImportProposal(Data data, Unit u, String desc,
        String name, String version);

    shared formal AbstractModuleImportUtil<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange> importUtil;
    
    shared void applyChanges(Project project, Unit u, String moduleName) {
        importUtil.exportModuleImports(project, u.\ipackage.\imodule, moduleName);
    }
    
    shared void addExportModuleImportProposal(Data data) {
        if (is Tree.SimpleType node = data.node) {
            value dec = (node).declarationModel;
            addExportModuleImportProposalInternal(data, node.unit, dec);
        }
    }

    shared void addExportModuleImportProposalForSupertypes(Data data) {
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

    void addExportModuleImportProposalInternal(Data data, Unit unit, Declaration dec) {
        
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

        newExportModuleImportProposal(data, unit, desc, 
            decModule.nameAsString, decModule.version);
    }

}
