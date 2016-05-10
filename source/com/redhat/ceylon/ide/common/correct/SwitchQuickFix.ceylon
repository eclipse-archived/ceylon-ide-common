import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil,
    Type
}
import java.util {
    List,
    Collections
}


shared interface SwitchQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        DefaultRegion region);
 
    shared void addElseProposal(Data data, IFile file) {
        if (is Tree.SwitchClause node = data.node, 
            is Tree.SwitchStatement st = nodes.findStatement(data.rootNode, node)) {
            
            value offset = st.endIndex.intValue();
            value tfc = newTextChange("Add Else", file);
            value doc = getDocumentForChange(tfc);
            value text = indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc) + "else {}";
            addEditToChange(tfc, newInsertEdit(offset, text));
            value selection = DefaultRegion(offset + text.size - 1, 0);
            
            newProposal(data, "Add 'else' clause", tfc, selection);
        }
        //TODO: else handle switch *expressions* 
    }

    shared void addCasesProposal(Data data, IFile file) {
        //TODO: handle switch expressions!
        if (is Tree.SwitchClause sc = data.node, 
            is Tree.SwitchStatement ss = nodes.findStatement(data.rootNode, sc), 
            exists e = sc.switched.expression, 
            exists _type = e.typeModel) {
            
            value scl = ss.switchCaseList;
            variable value type = _type;
            
            for (cc in scl.caseClauses) {
                value item = cc.caseItem;
                
                if (is Tree.IsCase ic = item) {
                    if (exists tn = ic.type) {
                        value t = tn.typeModel;
                        
                        if (!ModelUtil.isTypeUnknown(t)) {
                            type = type.minus(t);
                        }
                    }
                } else if (is Tree.MatchCase item) {
                    value ic = item;
                    value il = ic.expressionList;
                    for (Tree.Expression? ex in il.expressions) {
                        if (exists ex, 
                            exists t = ex.typeModel,
                            !ModelUtil.isTypeUnknown(t)) {
                            
                            type = type.minus(t);
                        }
                    }
                }
            }
            
            value tfc = newTextChange("Add Cases", file);
            value doc = getDocumentForChange(tfc);
            variable value text = "";
            variable List<Type> list;
            
            if (exists cts = type.caseTypes) {
                list = cts;
            } else {
                list = Collections.singletonList(type);
            }
            
            for (pt in list) {
                value \iis = if (pt.declaration.anonymous) then "" else "is ";
                value unit = data.rootNode.unit;
                text += indents.getDefaultLineDelimiter(doc) 
                        + indents.getIndent(data.node, doc)
                        + "case (" + \iis + pt.asString(unit) + ") {}";
            }
            
            value offset = ss.endIndex.intValue();
            addEditToChange(tfc, newInsertEdit(offset, text));
            
            newProposal(data, "Add missing 'case' clauses", tfc, 
                DefaultRegion(offset + text.size - 1, 0));
        }
    }
}
