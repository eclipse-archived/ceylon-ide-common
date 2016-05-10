import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    overloads,
    getRefinementTextFor
}
import com.redhat.ceylon.ide.common.util {
    FindBodyContainerVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Unit
}

import java.util {
    HashSet
}

shared interface RefineEqualsHashQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    TextChange? refineEqualsHash(Data data, IFile file, Integer currentOffset) {

        value change = newTextChange("Refine Equals and Hash", file);
        initMultiEditChange(change);
        
        value node = data.node;
        
        Tree.Body? body;
        variable Integer offset;
        if (is Tree.ClassDefinition node) {
            value classDefinition = node;
            body = classDefinition.classBody;
            offset = -1;
        } else if (is Tree.InterfaceDefinition node) {
            value interfaceDefinition = node;
            body = interfaceDefinition.interfaceBody;
            offset = -1;
        } else if (is Tree.ObjectDefinition node) {
            value objectDefinition = node;
            body = objectDefinition.classBody;
            offset = -1;
        } else if (is Tree.ObjectExpression node) {
            value objectExpression = node;
            body = objectExpression.classBody;
            offset = -1;
        } else if (is Tree.ClassBody|Tree.InterfaceBody node) {
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
        value document = getDocumentForChange(change);
        value bodyIndent = indents.getIndent(node, document);
        value delim = indents.getDefaultLineDelimiter(document);
        if (statements.empty) {
            indent = delim + bodyIndent + indents.defaultIndent;
            if (offset < 0) {
                offset = body.startIndex.intValue() + 1;
            }
        } else {
            value statement = statements.get(statements.size() - 1);
            indent = delim + indents.getIndent(statement, document);
            if (offset < 0) {
                offset = statement.endIndex.intValue();
            }
        }
        
        value result = StringBuilder();
        value already = HashSet<Declaration>();
        assert (is ClassOrInterface ci = node.scope);
        value unit = node.unit;
        value equals = ci.getMember("equals", null, false);
        value hash = ci.getMember("hash", null, false);
        for (dec in [equals, hash]) {
            for (d in overloads(dec)) {
                if (ci.isInheritedFromSupertype(d)) {
                    appendRefinementText(isInterface, indent, result, ci, unit, d);
                    importProposals.importSignatureTypes(d, data.rootNode, already);
                }
            }
        }
        
        if (getDocContent(document, offset, 1) == "}", result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, data.rootNode, document);
        addEditToChange(change, newInsertEdit(offset, result.string));
        
        return change;
    }
    
    void appendRefinementText(Boolean isInterface, String indent, StringBuilder result,
        ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = completionManager.getRefinedProducedReference(ci, member);
        value rtext = getRefinementTextFor(member, pr, unit, isInterface, ci,
            indent, true, true, indents, false);
        result.append(indent).append(rtext).append(indent);
    }
    
    shared void addRefineEqualsHashProposal(Data data, IFile file, Integer currentOffset) {
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
                
                value change = refineEqualsHash(data, file, currentOffset);
                
                if (exists change) {
                    newProposal(data, desc, change);
                }
            }
        }
    }

}