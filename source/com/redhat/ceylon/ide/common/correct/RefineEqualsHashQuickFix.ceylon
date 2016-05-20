import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    overloads,
    getRefinementTextFor,
    getRefinedProducedReference
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
import com.redhat.ceylon.ide.common.platform {
    TextChange,
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared object refineEqualsHashQuickFix {

    TextChange? refineEqualsHash(QuickFixData data, Integer currentOffset) {

        value change = platformServices.createTextChange("Refine Equals and Hash", data.phasedUnit);
        change.initMultiEdit();
        
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
        value document = change.document;
        value bodyIndent = document.getIndent(node);
        value delim = document.defaultLineDelimiter;
        if (statements.empty) {
            indent = delim + bodyIndent + platformServices.defaultIndent;
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
        
        value result = StringBuilder();
        value already = HashSet<Declaration>();
        assert (is ClassOrInterface ci = node.scope);
        value unit = node.unit;
        value equals = ci.getMember("equals", null, false);
        value hash = ci.getMember("hash", null, false);
        for (dec in [equals, hash]) {
            for (d in overloads(dec)) {
                if (ci.isInheritedFromSupertype(d)) {
                    appendRefinementText(data, isInterface, indent, result, ci, unit, d);
                    importProposals.importSignatureTypes(d, data.rootNode, already);
                }
            }
        }
        
        if (document.getText(offset, 1) == "}", result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, data.rootNode, document);
        change.addEdit(InsertEdit(offset, result.string));
        
        return change;
    }
    
    void appendRefinementText(QuickFixData data, Boolean isInterface, String indent,
        StringBuilder result, ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = getRefinedProducedReference(ci, member);
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
                
                value change = refineEqualsHash(data, currentOffset);
                
                if (exists change) {
                    data.addQuickFix {
                        description = desc;
                        change = change;
                        image = Icons.refinement;
                        kind = addRefineEqualsHash;
                    };
                }
            }
        }
    }

}