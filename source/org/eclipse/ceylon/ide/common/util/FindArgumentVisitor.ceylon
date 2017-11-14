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
    Node,
    Tree
}

class FindArgumentVisitor(Node term) extends Visitor() {
    
    shared variable Tree.NamedArgument? declaration = null;
    variable Tree.NamedArgument? current = null;
    
    shared actual void visit(Tree.NamedArgument that) {
        Tree.NamedArgument? myOuter = current;
        current = that;
        super.visit(that);
        current = myOuter;
    }
    
    shared actual void visitAny(Node node) {
        if (node == term) {
            declaration = current;
        }
        
        if (!exists d = declaration) {
            super.visitAny(node);
        }
    }
}