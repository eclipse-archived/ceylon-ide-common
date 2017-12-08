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
    Visitor,
    Node,
    Tree
}
import java.lang {
    overloaded
}

shared class FindBodyContainerVisitor(Node node) extends Visitor() {
    
    shared variable Tree.Declaration? declaration = null;
    variable Tree.Declaration? currentDeclaration = null;

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AttributeGetterDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.MethodDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.Constructor that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.ClassDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }

    overloaded
    shared actual void visit(Tree.InterfaceDefinition that) {
        Tree.Declaration? d = currentDeclaration;
        currentDeclaration = that;
        super.visit(that);
        currentDeclaration = d;
    }
    
    shared actual void visitAny(Node node) {
        if (this.node == node) {
            declaration = currentDeclaration;
        }
        if (!exists d = declaration) {
            super.visitAny(node);
        }
    }
}
