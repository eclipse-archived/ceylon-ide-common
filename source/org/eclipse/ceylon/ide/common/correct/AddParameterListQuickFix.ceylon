/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
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
                    params.append(ud.name else "unknwon");
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
                    kind = QuickFixKind.addParameterList;
                };
            }
        }
    }

    
}