import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

shared interface ChangeToQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void changeToFunction(Data data, IFile file) {
        value dec = nodes.findDeclarationWithBody(data.rootNode, data.node);
        
        if (is Tree.AnyMethod m = dec) {
            assert(is Tree.Return ret = data.node);

            if (is Tree.VoidModifier type = m.type) {
                value tfc = newTextChange("Change To Function", file);
                value unit = data.rootNode.unit;
                value rt = ret.expression.typeModel;
                addEditToChange(tfc, newReplaceEdit(
                    type.startIndex.intValue(), 
                    type.distance.intValue(),
                    if (ModelUtil.isTypeUnknown(rt)) then "function" else rt.asSourceCodeString(unit))
                );
                newProposal(data, "Make function non-'void'", tfc);
            }
        }
    }

    shared void changeToVoid(Data data, IFile file) {
        value dec = nodes.findDeclarationWithBody(data.rootNode, data.node);
        
        if (is Tree.AnyMethod dec) {
            value type = dec.type;
            
            if (!(type is Tree.VoidModifier)) {
                value tfc = newTextChange("Change To Void", file);
                addEditToChange(tfc, newReplaceEdit(
                    type.startIndex.intValue(), type.distance.intValue(), "void"));
                
                newProposal(data, "Make function 'void'", tfc);
            }
        }
    }
}
