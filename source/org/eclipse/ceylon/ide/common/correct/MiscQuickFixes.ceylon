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
    Visitor,
    Tree
}

// TODO rename to something like BlockQuickFix?
shared object miscQuickFixes {
    
    shared void addAnonymousFunctionProposals(QuickFixData data) {
        variable value currentOffset = data.node.startIndex.intValue();
        
        class FindAnonFunctionVisitor() extends Visitor() {
            variable shared Tree.FunctionArgument? result = null;
            
            shared actual void visit(Tree.FunctionArgument that) {
                if (currentOffset >= that.startIndex.intValue(),
                    currentOffset <= that.endIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        }
        
        value v = FindAnonFunctionVisitor();
        v.visit(data.rootNode);
        
        if (exists fun = v.result) {
            if (fun.expression exists) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, fun);
            }
            
            if (fun.block exists) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, fun.block, true);
            }
        }
    }

    shared void addDeclarationProposals(QuickFixData data, Tree.Declaration? decNode, Integer currentOffset) {
        if (!exists decNode) {
            return;
        }
        
        if (exists al = decNode.annotationList,
            exists endIndex = al.endIndex?.intValue(),
            currentOffset <= endIndex) {
            
            return;
        }
        
        if (is Tree.TypedDeclaration tdn = decNode,
            exists type = tdn.type,
            exists endIndex = type.endIndex?.intValue(),
            currentOffset <= endIndex) {
            
            return;
        }
        
        switch (decNode)
        case(is Tree.AttributeDeclaration) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierOrInitializerExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, decNode);
            } else {
                convertToGetterQuickFix.addConvertToGetterProposal(data, decNode);
            }
        }
        case (is Tree.MethodDeclaration) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, decNode);
            }
        }
        case (is Tree.AttributeSetterDefinition) {
            if (is Tree.LazySpecifierExpression se = decNode.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, decNode);
            }
            
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, b);
            }
        }
        case (is Tree.AttributeGetterDefinition) {
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, b);
            }
        }
        case (is Tree.MethodDefinition) {
            if (exists b = decNode.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, b);
            }
        }
        else {
        }
    }
    
    shared void addArgumentProposals(QuickFixData data, Tree.StatementOrArgument? node) {
        addArgumentBlockProposals(data, node);
        addArgumentFillInProposals(data, node);
    }

    shared void addArgumentBlockProposals(QuickFixData data, Tree.StatementOrArgument? node) {
        if (is Tree.MethodArgument node) {
            if (is Tree.LazySpecifierExpression se = node.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, node);
            }
            
            if (exists b = node.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, b);
            }
        }
        
        if (is Tree.AttributeArgument node) {
            if (is Tree.LazySpecifierExpression se = node.specifierExpression) {
                convertToBlockQuickFix.addConvertToBlockProposal(data, node);
            }
            
            if (exists b = node.block) {
                convertToSpecifierQuickFix.addConvertToSpecifierProposal(data, b);
            }
        }
    }
    
    shared void addArgumentFillInProposals(QuickFixData data, Tree.StatementOrArgument? node) {
        if (is Tree.SpecifiedArgument node) {
            fillInArgumentNameQuickFix.addFillInArgumentNameProposal(data, node);
        }
    }
}
