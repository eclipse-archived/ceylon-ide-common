import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
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

shared object refineFormalMembersQuickFix {
    
    shared void addRefineFormalMembersProposal(QuickFixData data, Boolean ambiguousError) {
        value n = data.node;
        Node? node;
        if (n is Tree.ClassBody
            | Tree.InterfaceBody
            | Tree.ClassDefinition
            | Tree.InterfaceDefinition
            | Tree.ObjectDefinition
            | Tree.ObjectExpression) {
            
            node = n;
        } else {
            value v = FindBodyContainerVisitor(n);
            data.rootNode.visit(v);
            node = v.declaration;
        }
        
        if (exists node,
            is ClassOrInterface ci = node.scope,
            exists cin = ci.name) {
            
            String name = if (cin.startsWith("anonymous#"))
                          then "anonymous class"
                          else "'" + cin + "'";
            
            String desc = if (ambiguousError)
                          then "Refine inherited ambiguous and formal members of " + name
                          else "Refine inherited formal members of " + name;
            
            value callback = void() {
                refineFormalMembers(data, data.editorSelection.start)
                    ?.apply();
            };
            data.addQuickFix {
                description = desc;
                change = callback;
                image = Icons.formalRefinement;
                kind = addRefineFormal;
            };
        }
    }
    
    shared TextChange? refineFormalMembers(QuickFixData data, Integer editorOffset) {
        
        value rootNode = data.rootNode;
        value node = data.node;
        value change = platformServices.createTextChange("Refine Members", data.document);

        change.initMultiEdit();
        
        //TODO: copy/pasted from CeylonQuickFixAssistant
        Tree.Body? body;
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
            return null;
        }
        if (!exists body) {
            return null;
        }
        value isInterface = body is Tree.InterfaceBody;
        value statements = body.statements;
        value document = data.document;
        String indent;
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
        value ambiguousNames = HashSet<String>();

        //TODO: does not return unrefined overloaded  
        //      versions of a method with one overlaad
        //      already refined
        value proposals = ci.getMatchingMemberDeclarations(unit, ci, "", 0).values();
        
        for (dwp in proposals) {
            value dec = dwp.declaration;
            for (d in overloads(dec)) {
                try {
                    if (d.formal, ci.isInheritedFromSupertype(d)) {
                        appendRefinementText(data, isInterface, indent, result, ci, unit, d);
                        importProposals.importSignatureTypes(d, rootNode, already);
                        ambiguousNames.add(d.name);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        for (superType in ci.supertypeDeclarations) {
            for (m in superType.members) {
                try {
                    if (exists name = m.name, m.shared) {
                        value doesntRefine =
                                if (exists r = ci.getMember(m.name, null, false))
                                then !r.refines(m) && !r.container.equals(ci)
                                else true;
                        
                        if (doesntRefine && ambiguousNames.add(m.name)) {
                            appendRefinementText(data, isInterface, indent, result, ci, unit, m);
                            importProposals.importSignatureTypes(m, rootNode, already);
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        
        if (document.getChar(offset) == '}', result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, rootNode, document);
        change.addEdit(InsertEdit(offset, result.string));
        
        return change;
    }
    
    void appendRefinementText(QuickFixData data, Boolean isInterface, String indent,
        StringBuilder result, ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = getRefinedProducedReference(ci, member);
        value rtext = getRefinementTextFor(member, pr, unit, isInterface,
            ci, indent, true, true, true);
        
        result.append(indent).append(rtext).append(indent);
    }
}
