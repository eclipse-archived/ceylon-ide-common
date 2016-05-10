import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}
import com.redhat.ceylon.model.typechecker.util {
    TypePrinter
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface ExpandTypeQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared void addExpandTypeProposal(Data data, IFile file, Tree.Statement? node,
        Integer selectionStart, Integer selectionStop) {
        
        if (!exists node) {
            return;
        }
        variable Tree.Type? result = null;
        
        node.visit(object extends Visitor() {
            shared actual void visit(Tree.Type that) {
                super.visit(that);
                value start = that.startIndex?.intValue();
                value stop = that.endIndex?.intValue();
                if (exists start, exists stop,
                    selectionStart <= start,
                    selectionStop >= stop) {
                    
                    result = that;
                }
            }
        });
        
        if (exists res = result) {
            value type = res.typeModel;
            value start = res.startIndex.intValue();
            value len = res.distance.intValue();
            value change = newTextChange("Expand Type", file);
            value doc = getDocumentForChange(change);
            value text = getDocContent(doc, start, len);
            
            value unabbreviated = TypePrinter(false).print(type, node.unit);
            
            if (unabbreviated != text) {
                addEditToChange(change, newReplaceEdit(start, len, unabbreviated));
                
                newProposal(data, "Expand type abbreviation", change, 
                    DefaultRegion(start, unabbreviated.size));
            }
        }
    }
}