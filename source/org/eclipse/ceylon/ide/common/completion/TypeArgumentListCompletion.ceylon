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
    Node,
    Tree,
    Visitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Functional,
    Scope
}
import java.lang {
    overloaded
}

shared interface TypeArgumentListCompletions {
    
    shared void addTypeArgumentListProposal(Integer offset, CompletionContext ctx, Node node,
        Scope scope) {

        if (!node.token exists) {
            return;
        }

        value start = node.startIndex.intValue();
        value stop = node.endIndex.intValue();

        value document = ctx.commonDocument;
        value typeArgText = document.getText {
            offset = start;
            length = stop - start;
        };

        value upToDateAndTypechecked = ctx.typecheckedRootNode;
        if (!exists upToDateAndTypechecked) {
            return;
        }
        
        object extends Visitor() {

            overloaded
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                if (exists startIndex = that.typeArguments?.startIndex?.intValue(),
                    startIndex == start,
                    is Functional d = that.declaration,
                    exists pr = that.target) {

                    for (dec in overloads(d)) {
                        completionManager.addInvocationProposals {
                            offset = offset;
                            prefix = document.getText {
                                offset = that.identifier.startIndex.intValue();
                                length = that.endIndex.intValue()
                                       - that.identifier.startIndex.intValue();
                            };
                            ctx = ctx;
                            dwp = null;
                            dec = dec;
                            reference = pr;
                            scope = scope;
                            ol = null;
                            typeArgs = typeArgText;
                            isMember = false;
                        };
                    }
                }
                super.visit(that);
            }

            overloaded
            shared actual void visit(Tree.SimpleType that) {
                if (exists startIndex = that.typeArgumentList?.startIndex?.intValue(),
                    startIndex == start,
                    is Functional d = that.declarationModel) {

                    for (dec in overloads(d)) {
                        completionManager.addInvocationProposals {
                            offset = offset;
                            prefix = document.getText {
                                offset = that.startIndex.intValue();
                                length = that.endIndex.intValue()
                                       - that.startIndex.intValue(); };
                            ctx = ctx;
                            dwp = null;
                            dec = dec;
                            reference = that.typeModel;
                            scope = scope;
                            ol = null;
                            typeArgs = typeArgText;
                            isMember = false;
                        };
                    }
                }
                super.visit(that);
            }
        }.visit(upToDateAndTypechecked);
    }
}
