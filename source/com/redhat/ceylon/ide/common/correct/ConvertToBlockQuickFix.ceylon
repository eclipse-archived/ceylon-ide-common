import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    Function,
    Value
}

shared object convertToBlockQuickFix {
    
    shared void addConvertToBlockProposal(QuickFixData data, Node decNode) {
        value change 
                = platformServices.document.createTextChange {
            name = "Convert to Block";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        
        Integer offset;
        Integer length;
        String semi;
        Boolean isVoid;
        String? addedKeyword;
        switch (decNode)
        case (is Tree.MethodDeclaration) {
            Function? dm = decNode.declarationModel;
            if (!exists dm) {
                return;
            }
            if (dm.parameter) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            value pls = decNode.parameterLists;
            if (pls.empty) {
                return;
            }
            

            if (exists tcl = decNode.typeConstraintList) {
                offset = tcl.endIndex.intValue();
            }
            else {
                offset = pls.get(pls.size() - 1).endIndex.intValue();
            }
            
            length = decNode.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
            addedKeyword = null;
        }
        case (is Tree.AttributeDeclaration) {
            Value? dm = decNode.declarationModel;
            if (!exists dm) {
                return;
            }
            if (dm.parameter) {
                return;
            }
            
            isVoid = false;
            offset = decNode.identifier.endIndex.intValue();
            length = decNode.specifierOrInitializerExpression.expression.startIndex.intValue() - offset;
            semi = "";
            addedKeyword = null;
        }
        case (is Tree.AttributeSetterDefinition) {
            isVoid = true;
            offset = decNode.identifier.endIndex.intValue();
            length = decNode.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
            addedKeyword = null;
        }
        case (is Tree.MethodArgument) {
            Function? dm = decNode.declarationModel;
            if (!exists dm) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            if (!decNode.type.token exists) {
                addedKeyword = "function ";
            }
            else {
                addedKeyword = null;
            }
            
            value pls = decNode.parameterLists;
            if (pls.empty) {
                return;
            }
            
            offset = pls.get(pls.size() - 1).endIndex.intValue();
            length = decNode.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        }
        case (is Tree.AttributeArgument) {
            isVoid = false;
            if (!decNode.type.token exists) {
                addedKeyword = "value ";
            }
            else {
                addedKeyword = null;
            }
            
            offset = decNode.identifier.endIndex.intValue();
            length = decNode.specifierExpression.expression.startIndex.intValue() - offset;
            semi = "";
        }
        case (is Tree.FunctionArgument) {
            Function? dm = decNode.declarationModel;
            if (!exists dm) {
                return;
            }
            
            isVoid = dm.declaredVoid;
            value pls = decNode.parameterLists;
            if (pls.empty) {
                return;
            }
            
            if (exists tcl = decNode.typeConstraintList) {
                offset = tcl.endIndex.intValue();
            }
            else {
                offset = pls.get(pls.size() - 1).endIndex.intValue();
            }
            
            length = decNode.expression.startIndex.intValue() - offset;
            semi = ";";
            addedKeyword = null;
        }
        else {
            return;
        }
        
        if (exists addedKeyword) {
            change.addEdit(InsertEdit {
                start = decNode.startIndex.intValue();
                text = addedKeyword;
            });
        }
        
        value doc = change.document;
        value baseIndent = doc.getIndent(decNode);
        value indent = platformServices.document.defaultIndent;
        value nl = doc.defaultLineDelimiter;
        change.addEdit(ReplaceEdit {
            start = offset;
            length = length;
            text = " {" + nl
                + baseIndent + indent 
                + (if (isVoid) then "" else "return ");
        });
        change.addEdit(InsertEdit {
            start = decNode.endIndex.intValue();
            text = semi + nl + baseIndent + "}";
        });
        
        data.addQuickFix {
            description = decNode is Tree.FunctionArgument
                then "Convert anonymous function => to block"
                else "Convert => to block";
            change = change;
            selection = DefaultRegion {
                start = offset + 2 + nl.size + baseIndent.size + indent.size;
                length = 0;
            };
        };
    }

}