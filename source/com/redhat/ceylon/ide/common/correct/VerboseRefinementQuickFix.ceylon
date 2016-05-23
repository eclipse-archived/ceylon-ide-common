import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    DeleteEdit
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

shared object verboseRefinementQuickFix {
    
    shared void addVerboseRefinementProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.SpecifierStatement ss = statement,
            ss.refinement, 
            exists e = ss.specifierExpression.expression,
            !ModelUtil.isTypeUnknown(e.typeModel)) {
            
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Verbose Refinement";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            value unit = ss.unit;
            value type = unit.denotableType(e.typeModel);
            value importProposals 
                    = CommonImportProposals {
                        document = data.document;
                        rootNode = data.rootNode;
                    };
            importProposals.importType(type);
            importProposals.apply(change);
            
            change.addEdit(InsertEdit {
                start = ss.startIndex.intValue();
                text = "shared actual ``type.asSourceCodeString(unit)`` ";
            });
            
            data.addQuickFix("Convert to verbose refinement", change);
        }
    }

    shared void addShortcutRefinementProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.TypedDeclaration statement,
            exists model = statement.declarationModel,
            model.actual, 
            if (is Tree.AnyMethod statement)
                then !statement.typeParameterList exists 
                else true,
            exists spec = 
                    switch (statement) 
                    case (is Tree.AttributeDeclaration) 
                        statement.specifierOrInitializerExpression
                    case (is Tree.MethodDeclaration) 
                        statement.specifierExpression
                    else null,
            exists expr = spec.expression,
            !ModelUtil.isTypeUnknown(expr.typeModel)) {
            
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Shortcut Refinement";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            value start = statement.startIndex.intValue();
            value length = statement.identifier.startIndex.intValue() - start;
            change.addEdit(DeleteEdit {
                start = start;
                length = length;
            });
            
            data.addQuickFix("Convert to shortcut refinement", change);
        }
    }
}