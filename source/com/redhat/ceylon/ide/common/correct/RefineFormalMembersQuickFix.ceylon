import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager,
    overloads,
    getRefinementTextFor
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Unit
}

import java.lang {
    Character
}
import java.util {
    HashSet
}

shared ClassOrInterface? getRefineFormalMembersScope(Node node) {
    if (node is Tree.ClassBody
        || node is Tree.InterfaceBody
            || node is Tree.ClassDefinition
            || node is Tree.InterfaceDefinition
            || node is Tree.ObjectDefinition
            || node is Tree.ObjectExpression) {
        
        if (is ClassOrInterface ci = node.scope) {
            return ci;
        }
    }
    
    return null;
}
shared interface RefineFormalMembersQuickFix<Document,InsertEdit,TextEdit,TextChange>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit {
    
    shared formal Indents<Document> indents;
    shared formal IdeCompletionManager<out Object,out Object,out Object,Document> completionManager;
    shared formal ImportProposals<out Object,out Object,Document,InsertEdit,TextEdit,TextChange> importProposals;
    shared formal Character getDocChar(Document doc, Integer offset);
    
    shared String? getName(Node node, Boolean ambiguousError) {
        assert(exists ci = getRefineFormalMembersScope(node));
        String name = if (ci.name.startsWith("anonymous#"))
                      then "anonymous class"
                      else "'" + ci.name + "'";
        
        return if (ambiguousError)
               then "Refine inherited ambiguous and formal members of " + name
               else "Refine inherited formal members of " + name;
    }
    
    shared void refineFormalMembers(Document document, TextChange change, Tree.CompilationUnit? rootNode,
        Node node, Integer editorOffset) {
        
        if (!exists r = rootNode) {
            return;
        }
        assert (exists rootNode);
        initMultiEditChange(change);
        
        Tree.Body body;
        variable Integer offset;
        if (is Tree.ClassDefinition node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.InterfaceDefinition node) {
            body = (node).interfaceBody;
            offset = -1;
        } else if (is Tree.ObjectDefinition node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.ObjectExpression node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.ClassBody|Tree.InterfaceBody node) {
            body = node;
            offset = editorOffset;
        } else {
            return;
        }
        value isInterface = body is Tree.InterfaceBody;
        value statements = body.statements;
        String indent;
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
        value ambiguousNames = HashSet<String>();
        value proposals = completionManager.getProposals(node, ci, "", false, rootNode).values();
        
        for (dwp in CeylonIterable(proposals)) {
            value dec = dwp.declaration;
            for (d in overloads(dec)) {
                try {
                    if (d.formal, ci.isInheritedFromSupertype(d)) {
                        appendRefinementText(isInterface, indent, result, ci, unit, d);
                        importProposals.importSignatureTypes(d, rootNode, already);
                        ambiguousNames.add(d.name);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        for (superType in CeylonIterable(ci.supertypeDeclarations)) {
            for (m in CeylonIterable(superType.members)) {
                try {
                    if (m.shared) {
                        Declaration? r = ci.getMember(m.name, null, false);
                        value foo = if (exists r) then !r.refines(m) && !r.container.equals(ci) else true;
                        
                        if (foo && ambiguousNames.add(m.name)) {
                            appendRefinementText(isInterface, indent, result, ci, unit, m);
                            importProposals.importSignatureTypes(m, rootNode, already);
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        
        if (getDocChar(document, offset) == '}', result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, rootNode, document);
        addEditToChange(change, newInsertEdit(offset, result.string));
    }
    
    void appendRefinementText(Boolean isInterface, String indent, StringBuilder result,
        ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = completionManager.getRefinedProducedReference(ci, member);
        value rtext = getRefinementTextFor(member, pr, unit, isInterface, ci, indent, true,
            true, indents, true);
        
        result.append(indent).append(rtext).append(indent);
    }
}
