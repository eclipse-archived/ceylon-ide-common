import com.redhat.ceylon.compiler.typechecker.tree {
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
    ModelUtil,
    Type
}

shared object assertExistsDeclarationQuickFix {

    void addSplitDeclarationProposal(QuickFixData data, 
        Tree.AttributeDeclaration decNode) {
        
        if (exists dec = decNode.declarationModel,
            exists sie 
                = decNode.specifierOrInitializerExpression,
            exists ex = sie.expression, 
            !dec.parameter && !dec.toplevel) {
            
            Type? siet = ex.typeModel;        
            value unit = data.rootNode.unit;
            String existsOrNonempty;
            String changeDesc;
            if (ModelUtil.isTypeUnknown(siet)) {
                return;
            }
            else if (unit.isOptionalType(siet)) {
                existsOrNonempty = "exists";
                changeDesc = "Assert Exists";
            }
            else if (unit.isPossiblyEmptyType(siet)) {
                existsOrNonempty = "nonempty";
                changeDesc = "Assert Nonempty";
            }
            else {
                return;
            }
            
            if (exists id = decNode.identifier,
                id.token exists) {
                
                value change 
                        = platformServices.createTextChange {
                    name = changeDesc;
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
                
                value idEndOffset = id.endIndex.intValue();
                value semiOffset = decNode.endIndex.intValue() - 1;
                value type = decNode.type;
                value typeOffset = type.startIndex.intValue();
                value typeLen = type.distance.intValue();
                change.addEdit(ReplaceEdit {
                    start = typeOffset;
                    length = typeLen;
                    text = "assert (" + existsOrNonempty;
                });
                change.addEdit(InsertEdit {
                    start = semiOffset;
                    text = ")";
                });
                
                data.addQuickFix {
                    desc = "Change to 'assert (``existsOrNonempty`` ``dec.name``)'";
                    change = change;
                    selection = DefaultRegion {
                        start = idEndOffset + 8 + existsOrNonempty.size - typeLen;
                    };
                };
            }
        }
    }
    
    shared void addAssertExistsDeclarationProposals(QuickFixData data, 
        Tree.Declaration? decNode) {
        if (is Tree.AttributeDeclaration decNode, 
            exists dec = decNode.declarationModel, 
            decNode.specifierOrInitializerExpression exists || dec.parameter) {
            addSplitDeclarationProposal(data, decNode);
        }
    }
}