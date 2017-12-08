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
import org.eclipse.ceylon.model.typechecker.model {
    FunctionOrValue
}

shared object addInitializerQuickFix {
    
    shared void addInitializerProposals(QuickFixData data) {
        switch (node = data.node)
        case (is Tree.AttributeDeclaration) {
            Tree.SpecifierOrInitializerExpression? sie 
                    = node.specifierOrInitializerExpression;
            if (!(sie is Tree.LazySpecifierExpression)) {
                addInitializerProposal(data, node);
            }
        }
        case (is Tree.MethodDeclaration) {
            addInitializerProposal(data, node);
        }
        else {}
    }

    void addInitializerProposal(QuickFixData data, 
        Tree.TypedDeclaration decNode) {
        
        if (is FunctionOrValue dec = decNode.declarationModel,
            !dec.parameter && !dec.formal) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Add Initializer";
                input = data.phasedUnit;
            };
            
            value offset = decNode.endIndex.intValue() - 1;
            value defaultValue 
                    = correctionUtil.defaultValue {
                        unit = data.rootNode.unit;
                        type = dec.type;
                    };
            
            value specifier 
                    = decNode is Tree.MethodDeclaration
                        then " => " else " = ";
            
            change.addEdit(InsertEdit {
                start = offset;
                text = specifier + defaultValue;
            });
            
            data.addQuickFix {
                description = "Add initializer to '``dec.name``'";
                change = change;
                selection = DefaultRegion {
                    start = offset + specifier.size;
                    length = defaultValue.size;
                };
            };
        }
    }

}