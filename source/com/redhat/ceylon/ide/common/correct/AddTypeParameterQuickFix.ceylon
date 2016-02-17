import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared interface AddTypeParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addTypeParameterProposal(Data data, IFile file) {
        assert (is Tree.TypeConstraint tcn = data.node);
        value tp = tcn.declarationModel;
        assert (is Tree.Declaration decNode = nodes.getReferencedNodeInUnit(
            tp.declaration, data.rootNode));
        
        Tree.TypeParameterList? tpl;
        if (is Tree.ClassOrInterface decNode) {
            value ci = decNode;
            tpl = ci.typeParameterList;
        } else if (is Tree.AnyMethod decNode) {
            value am = decNode;
            tpl = am.typeParameterList;
        } else if (is Tree.TypeAliasDeclaration decNode) {
            value ad = decNode;
            tpl = ad.typeParameterList;
        } else {
            return;
        }
        
        value tfc = newTextChange("Add Type Parameter", file);
        InsertEdit edit;
        if (!exists tpl) {
            value id = decNode.identifier;
            edit = newInsertEdit(id.endIndex.intValue(), "<" + tp.name + ">");
        } else {
            edit = newInsertEdit(tpl.endIndex.intValue() - 1, ", " + tp.name);
        }
        
        addEditToChange(tfc, edit);

        value desc = "Add '``tp.name``' to type parameter list of '``decNode.declarationModel.name``'";
        
        newProposal(data, desc, tfc);
    }
}
