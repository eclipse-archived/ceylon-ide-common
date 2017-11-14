/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.imports {
    moduleImportUtil
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit,
    Declaration
}

shared object exportModuleImportQuickFix {

    shared void addExportModuleImportProposal(QuickFixData data) {
        if (is Tree.SimpleType node = data.node,
            exists dec = node.declarationModel) {
            addExportModuleImportProposalInternal(data, node.unit, dec);
        }
    }

    shared void addExportModuleImportProposalForSupertypes(QuickFixData data) {
        variable Node? node = data.node;
        value unit = data.node.unit;
        value rootNode = data.rootNode;
        
        if (is Tree.InitializerParameter n = node) {
            node = nodes.getReferencedNode { 
                model = nodes.getReferencedModel(n); 
                rootNode = rootNode; 
            };
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
            if (mi.\imodule == decModule && mi.export) {
                return;
            }
        }
        
        data.addQuickFix {
            description
                    = "Export 'import ``decModule.nameAsString`` \"``decModule.version``\"' to clients of module";
            qualifiedNameIsPath = true;
            image = Icons.imports;
            change()
                => moduleImportUtil.exportModuleImports {
                    data = data;
                    target = unit.\ipackage.\imodule;
                    moduleName = decModule.nameAsString;
                };
            affectsOtherUnits = true;
        };
    }

}
