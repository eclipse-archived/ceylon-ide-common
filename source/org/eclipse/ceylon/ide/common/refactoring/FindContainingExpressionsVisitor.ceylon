/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    ArrayList
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}

import java.lang {
    ObjectArray
}

shared class FindContainingExpressionsVisitor(Integer offset) extends Visitor() {

    value myElements = ArrayList<Tree.Term>();
    
    shared ObjectArray<Tree.Term> elements => ObjectArray.with(myElements);
    
    shared actual void visit(Tree.Term that) {
        super.visit(that);
        
        if (!is Tree.Expression that,
                exists start = that.startIndex?.intValue(),
                exists end = that.endIndex?.intValue(),
                start <= offset && end >= offset) {
            myElements.add(that);
        }
    }
}