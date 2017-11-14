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
    Tree,
    Node,
    TreeUtil
}
import org.eclipse.ceylon.model.typechecker.model {
    Referenceable,
    Declaration
}
import java.lang {
    overloaded
}

shared class FindDeclarationNodeVisitor(Referenceable declaration) extends Visitor() {
    
    shared variable Tree.StatementOrArgument? declarationNode = null;
    
    Boolean isDeclaration(Declaration? dec) 
            => if (exists dec) then dec==declaration else false;

    overloaded
    shared actual void visit(Tree.Declaration that) {
        if (isDeclaration(that.declarationModel)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual default void visit(Tree.ObjectDefinition that) {
        if (isDeclaration(that.declarationModel?.typeDeclaration)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ModuleDescriptor that) {
        if (TreeUtil.formatPath(that.importPath.identifiers)
                == declaration.nameAsString) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.PackageDescriptor that) {
        if (TreeUtil.formatPath(that.importPath.identifiers)
                == declaration.nameAsString) {
            declarationNode = that;
        }
        super.visit(that);
    }
    
    shared actual void visitAny(Node node) {
        if (!exists n = declarationNode) {
            super.visitAny(node);
        }
    }

    overloaded
    shared actual void visit(Tree.SpecifierStatement that) {
        if (isDeclaration(that.declaration)) {
            declarationNode = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.Constructor that) {
        if (isDeclaration(that.constructor)) {
            declarationNode = that;
        }
        super.visit(that);
    }
}
