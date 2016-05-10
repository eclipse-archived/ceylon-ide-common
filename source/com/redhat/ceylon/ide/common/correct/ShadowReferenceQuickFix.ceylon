import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindReferencesVisitor
}

shared interface ShadowReferenceQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    value quickFixDesc => "Shadow reference inside control structure";
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        Integer offset, Integer length);

    shared void addShadowSwitchReferenceProposal(Data data, IFile file) {
        if (is Tree.Term node = data.node) {
            value statement = nodes.findStatement(data.rootNode, node);
            
            if (is Tree.SwitchStatement statement) {
                value name = nodes.nameProposals {
                    node = node;
                    rootNode = data.rootNode;
                }[0];
                value change = newTextChange("Shadow Reference", file);
                initMultiEditChange(change);
//                Integer offset = statement.getStartIndex();
//                change.addEdit(new ReplaceEdit(offset,
//                        node.getStartIndex()-offset,
//                        "value " + name + " = "));
//                IDocument doc = getDocument(change);
//                change.addEdit(new InsertEdit(node.getEndIndex(),
//                        ";" +
//                        getDefaultLineDelimiter(doc) +
//                        getIndent(statement, doc) +
//                        "switch (" + name));
                value ss = statement;
                value loc = node.startIndex.intValue();
                addEditToChange(change, newInsertEdit(loc, name + " = "));
                
                if (is Tree.BaseMemberExpression bme = node,
                    exists d = bme.declaration) {

                    value frv = FindReferencesVisitor(d);
                    frv.visit(ss.switchCaseList);
                    
                    for (n in frv.nodeSet) {
                        value identifyingNode = nodes.getIdentifyingNode(n);
                        
                        if (exists identifyingNode) {
                            value start = identifyingNode.startIndex.intValue();
                            if (start != loc) {
                                value len = identifyingNode.text.size;
                                addEditToChange(change, newReplaceEdit(start, len, name));
                            }
                        }
                    }
                }
                
                newProposal(data, quickFixDesc, change, loc, name.size);
            }
        }
    }

    shared void addShadowReferenceProposal(Data data, IFile file) {
        if (is Tree.Variable var = data.node) {
            value offset = var.identifier.startIndex.intValue();
            value term = var.specifierExpression.expression.term;
            value name = nodes.nameProposals {
                node = term;
                rootNode = data.rootNode;
            }[0];
            value change = newTextChange("Shadow Reference", file);
            initMultiEditChange(change);
            addEditToChange(change, newInsertEdit(offset, name + " = "));
            value statement = nodes.findStatement(data.rootNode, var);
            value dec = var.declarationModel;
            value frv = FindReferencesVisitor(dec);

            frv.visit(statement);
            for (n in frv.nodeSet) {
                value identifyingNode = nodes.getIdentifyingNode(n);
                
                if (exists identifyingNode) {
                    value start = identifyingNode.startIndex.intValue();
                    if (start != offset) {
                        value len = identifyingNode.text.size;
                        addEditToChange(change, newReplaceEdit(start, len, name));
                    }
                }
            }
            
            newProposal(data, quickFixDesc, change, offset, name.size);
        } else if (is Tree.Term node = data.node) {
            value name = nodes.nameProposals(node)[0];
            value change = newTextChange("Shadow Reference", file);
            value offset = node.startIndex.intValue();
            
            addEditToChange(change, newInsertEdit(offset, name + " = "));
            newProposal(data, quickFixDesc, change, offset, name.size);
        }
    }
}
