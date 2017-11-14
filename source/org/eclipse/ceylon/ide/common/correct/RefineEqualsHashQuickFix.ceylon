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
    HashSet
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import org.eclipse.ceylon.ide.common.completion {
    overloads,
    getRefinementTextFor,
    completionManager
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.platform {
    TextChange,
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.util {
    FindBodyContainerVisitor
}
import org.eclipse.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Unit
}

shared object refineEqualsHashQuickFix {

    TextChange? refineEqualsHash(QuickFixData data, Integer currentOffset) {

        value change = platformServices.document.createTextChange("Refine Equals and Hash", data.phasedUnit);
        change.initMultiEdit();
        
        value node = data.node;
        
        Tree.Body? body;
        variable Integer offset;
        switch (node)
        case (is Tree.ClassDefinition) {
            value classDefinition = node;
            body = classDefinition.classBody;
            offset = -1;
        } case (is Tree.InterfaceDefinition) {
            value interfaceDefinition = node;
            body = interfaceDefinition.interfaceBody;
            offset = -1;
        } case (is Tree.ObjectDefinition) {
            value objectDefinition = node;
            body = objectDefinition.classBody;
            offset = -1;
        } case (is Tree.ObjectExpression) {
            value objectExpression = node;
            body = objectExpression.classBody;
            offset = -1;
        } case (is Tree.ClassBody
                 | Tree.InterfaceBody) {
            body = node;
            offset = currentOffset;
        } else {
            return null;
        }
        
        if (!exists body) {
            return null;
        }
        
        value isInterface = body is Tree.InterfaceBody;
        value statements = body.statements;
        String indent;
        value document = change.document;
        value bodyIndent = document.getIndent(node);
        value delim = document.defaultLineDelimiter;
        if (statements.empty) {
            indent = delim + bodyIndent + platformServices.document.defaultIndent;
            if (offset < 0) {
                offset = body.startIndex.intValue() + 1;
            }
        } else {
            value statement = statements.get(statements.size() - 1);
            indent = delim + document.getIndent(statement);
            if (offset < 0) {
                offset = statement.endIndex.intValue();
            }
        }
        
        value result = StringBuilder().append(document.defaultLineDelimiter);
        value already = HashSet<Declaration>();
        assert (is ClassOrInterface ci = node.scope);
        value unit = node.unit;
        value equals = ci.getMember("equals", null, false);
        value hash = ci.getMember("hash", null, false);
        for (dec in [equals, hash]) {
            for (d in overloads(dec)) {
                if (ci.isInheritedFromSupertype(d)) {
                    appendRefinementText(data, isInterface, indent, result, ci, unit, d);
                    importProposals.importSignatureTypes(d, data.rootNode, already, ci);
                }
            }
        }
        
        // If the cursor is right after the closing brace, we have to insert
        // our declarations inside the body
        if (offset == body.endIndex.intValue()) {
            offset--;
        }
        
        if (document.getText(offset, 1) == "}", result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, data.rootNode, document, ci);
        change.addEdit(InsertEdit(offset, result.string));
        
        return change;
    }
    
    void appendRefinementText(QuickFixData data, Boolean isInterface, String indent,
        StringBuilder result, ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = completionManager.getRefinedProducedReference(ci, member);
        value rtext = getRefinementTextFor(member, pr, unit, isInterface, ci,
            indent, true, true, false);
        result.append(indent).append(rtext).append(indent);
    }
    
    shared void addRefineEqualsHashProposal(QuickFixData data, Integer currentOffset) {
        Node? node;
        if (is Tree.ClassBody|Tree.InterfaceBody|Tree.ClassDefinition
            |Tree.InterfaceDefinition|Tree.ObjectDefinition
            |Tree.ObjectExpression n = data.node) {
            
            node = n;
        } else {
            value v = FindBodyContainerVisitor(data.node);
            v.visit(data.rootNode);
            node = v.declaration;
        }
        
        if (exists node) {
            if (is ClassOrInterface ci = node.scope) {
                String? n = ci.name;
                String name;
                if (!exists n) {
                    return;
                } else if (n.startsWith("anonymous#")) {
                    name = "anonymous class";
                } else {
                    name = "'" + n + "'";
                }
                
                value equals = ci.getMember("equals", null, false);
                value hash = ci.getMember("hash", null, false);
                variable Boolean hasEquals = true;
                for (e in overloads(equals)) {
                    if (ci.isInheritedFromSupertype(e)) {
                        hasEquals = false;
                    }
                }
                
                variable Boolean hasHash = true;
                for (h in overloads(hash)) {
                    if (ci.isInheritedFromSupertype(h)) {
                        hasHash = false;
                    }
                }
                
                String desc;
                if (hasEquals, hasHash) {
                    return;
                } else if (hasEquals) {
                    desc = "Refine 'hash' attribute of " + name;
                } else if (hasHash) {
                    desc = "Refine 'equals()' method of " + name;
                } else {
                    desc = "Refine 'equals()' and 'hash' of " + name;
                }
                
                if (exists change = refineEqualsHash(data, currentOffset)) {
                    data.addQuickFix {
                        description = desc;
                        change = change;
                        image = Icons.refinement;
                        kind = QuickFixKind.addRefineEqualsHash;
                    };
                }
            }
        }
    }

} 