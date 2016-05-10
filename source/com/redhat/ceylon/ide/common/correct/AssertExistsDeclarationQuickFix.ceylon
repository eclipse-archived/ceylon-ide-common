import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ModelUtil,
    Type
}

shared interface AssertExistsDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    void addSplitDeclarationProposal(Data data, IFile file, Tree.AttributeDeclaration decNode) {
        Declaration? dec = decNode.declarationModel;
        Tree.SpecifierOrInitializerExpression? sie = decNode.specifierOrInitializerExpression;
        if (!exists dec) {
            return;
        }
        if (!exists sie) {
            return;
        }
        if (dec.parameter || dec.toplevel || !sie.expression exists) {
            return;
        }
        
        Type? siet = sie.expression.typeModel;
        String existsOrNonempty;
        String changeDesc;
        
        if (ModelUtil.isTypeUnknown(siet)) {
            return;
        } else if (data.rootNode.unit.isOptionalType(siet)) {
            existsOrNonempty = "exists";
            changeDesc = "Assert Exists";
        } else if (data.rootNode.unit.isPossiblyEmptyType(siet)) {
            existsOrNonempty = "nonempty";
            changeDesc = "Assert Nonempty";
        } else {
            return;
        }
        
        if (exists id = decNode.identifier,
            id.token exists) {
            
            value idEndOffset = id.endIndex.intValue();
            value semiOffset = decNode.endIndex.intValue() - 1;
            value change = newTextChange(changeDesc, file);
            initMultiEditChange(change);
            value type = decNode.type;
            value typeOffset = type.startIndex.intValue();
            value typeLen = type.distance.intValue();
            addEditToChange(change, newReplaceEdit(typeOffset, typeLen, "assert (" + existsOrNonempty));
            addEditToChange(change, newInsertEdit(semiOffset, ")"));
            
            value desc = "Change to 'assert (``existsOrNonempty`` ``dec.name``)'";
            value selection = idEndOffset + 8 + existsOrNonempty.size - typeLen;
            newProposal(data, desc, change, DefaultRegion(selection, 0));
        }
    }
    
    shared void addAssertExistsDeclarationProposals(Data data, IFile file, Tree.Declaration? decNode) {
        if (!exists decNode) {
            return;
        }
        
        if (exists dec = decNode.declarationModel,
            is Tree.AttributeDeclaration decNode) {

            Tree.SpecifierOrInitializerExpression? sie = decNode.specifierOrInitializerExpression;
            if (sie exists || dec.parameter) {
                addSplitDeclarationProposal(data, file, decNode);
            }
        }
    }
}