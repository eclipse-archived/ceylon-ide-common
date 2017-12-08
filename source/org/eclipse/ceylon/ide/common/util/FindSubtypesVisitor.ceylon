/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    HashSet
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import org.eclipse.ceylon.model.typechecker.model {
    TypeDeclaration
}

import java.util {
    JSet = Set
}
import ceylon.interop.java {
    JavaSet
}
import java.lang {
    overloaded
}

shared class FindSubtypesVisitor(TypeDeclaration declaration) extends Visitor() {
    value nodes = HashSet<Tree.Declaration|Tree.ObjectExpression>();
    
    shared Set<Tree.Declaration|Tree.ObjectExpression> declarationNodes => nodes;
    shared JSet<Tree.Declaration|Tree.ObjectExpression> declarationNodeSet => JavaSet(nodes);
    
    Boolean isRefinement(TypeDeclaration? dec) 
            => dec?.inherits(declaration) else false;

    overloaded
    shared actual void visit(Tree.TypeDeclaration that) {
        if (isRefinement(that.declarationModel)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        if (isRefinement(that.declarationModel.typeDeclaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ObjectExpression that) {
        if (exists t=that.typeModel, isRefinement(t.declaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
}
