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
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    InsertEdit,
    TextChange
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Type,
    Scope
}

shared class CommonImportProposals(CommonDocument document, Tree.CompilationUnit rootNode) {
    
    value imports = HashSet<Declaration>();
    
    shared Boolean isImported(Declaration declaration)
            => importProposals.isImported(declaration, rootNode.unit);

    shared List<InsertEdit> importEdits(
        {Declaration*} declarations,
        {String*}? aliases = null,
        Scope? scope = null,
        Declaration? declarationBeingDeleted = null)
            => importProposals.importEdits {
                rootNode = rootNode;
                declarations = declarations;
                aliases = aliases;
                declarationBeingDeleted = declarationBeingDeleted;
                scope = scope;
                doc = document;
            };
    
    shared void importDeclaration(Declaration declaration)
            => importProposals.importDeclaration {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importType(Type? type)
            => importProposals.importType {
                type = type;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importTypes({Type*} types)
            => importProposals.importTypes {
                types = types;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importSignatureTypes(Declaration declaration)
            => importProposals.importSignatureTypes {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
        
    shared Integer apply(TextChange change) 
            => importProposals.applyImports {
                change = change;
                declarations = imports;
                rootNode = rootNode;
                doc = document;
            };
}