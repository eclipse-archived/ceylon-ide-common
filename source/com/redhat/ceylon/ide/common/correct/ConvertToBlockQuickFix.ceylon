import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Function,
    Value
}
shared interface ConvertToBlockQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared void addConvertToBlockProposal(Data data, IFile file, Node decNode) {
        value change = newTextChange("Convert to Block", file);
        initMultiEditChange(change);
        variable Integer offset;
        Integer length;
        String semi;
        Boolean isVoid;
        variable String? addedKeyword = null;
        variable value desc = "Convert => to block";
        
        if (is Tree.MethodDeclaration md = decNode) {
            Function? dm = md.declarationModel;
            if (!exists dm) {
                return;
            }
            if (dm.parameter) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            value pls = md.parameterLists;
            if (pls.empty) {
                return;
            }
            
            offset = pls.get(pls.size() - 1).endIndex.intValue();

            if (exists tcl = md.typeConstraintList) {
                offset = tcl.endIndex.intValue();
            }
            
            length = md.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        } else if (is Tree.AttributeDeclaration ad = decNode) {
            Value? dm = ad.declarationModel;
            if (!exists dm) {
                return;
            }
            if (dm.parameter) {
                return;
            }
            
            isVoid = false;
            offset = ad.identifier.endIndex.intValue();
            length = ad.specifierOrInitializerExpression.expression.startIndex.intValue() - offset;
            semi = "";
        } else if (is Tree.AttributeSetterDefinition asd = decNode) {
            isVoid = true;
            offset = asd.identifier.endIndex.intValue();
            length = asd.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        } else if (is Tree.MethodArgument ma = decNode) {
            Function? dm = ma.declarationModel;
            if (!exists dm) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            if (!ma.type.token exists) {
                addedKeyword = "function ";
            }
            
            value pls = ma.parameterLists;
            if (pls.empty) {
                return;
            }
            
            offset = pls.get(pls.size() - 1).endIndex.intValue();
            length = ma.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        } else if (is Tree.AttributeArgument decNode) {
            value aa = decNode;
            isVoid = false;
            if (!aa.type.token exists) {
                addedKeyword = "value ";
            }
            
            offset = aa.identifier.endIndex.intValue();
            length = aa.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        } else if (is Tree.FunctionArgument decNode) {
            value fun = decNode;
            Function? dm = fun.declarationModel;
            
            if (!exists dm) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            value pls = fun.parameterLists;
            if (pls.empty) {
                return;
            }
            
            offset = pls.get(pls.size() - 1).endIndex.intValue();

            if (exists tcl = fun.typeConstraintList) {
                offset = tcl.endIndex.intValue();
            }
            
            length = fun.expression.startIndex.intValue() - offset;
            semi = ";";
            desc = "Convert anonymous function => to block";
        } else {
            return;
        }
        
        if (exists kw = addedKeyword) {
            value loc = decNode.startIndex.intValue();
            addEditToChange(change, newInsertEdit(loc, kw));
        }
        
        value doc = getDocumentForChange(change);
        value baseIndent = indents.getIndent(decNode, doc);
        value indent = indents.defaultIndent;
        value nl = indents.getDefaultLineDelimiter(doc);
        value text = " {" + nl
                + baseIndent + indent + (if (isVoid) then "" else "return ");
        addEditToChange(change, newReplaceEdit(offset, length, text));
        addEditToChange(change, newInsertEdit(decNode.endIndex.intValue(), 
            semi + nl + baseIndent + "}"));
        
        value newOffset = offset + 2 + nl.size + baseIndent.size + indent.size;
        newProposal(data, desc, change, DefaultRegion(newOffset, 0));
    }

}