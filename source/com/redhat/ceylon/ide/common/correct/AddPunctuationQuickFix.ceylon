import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    ReplaceEdit,
    platformUtils,
    Status
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object addPunctuationQuickFix {
    
    shared void addEmptyParameterListProposal(QuickFixData data) {
        if (is Tree.Declaration decNode = data.node) {

            value dec = decNode.declarationModel;
            value change
                    = platformServices.document.createTextChange {
                name = "Add Empty Parameter List";
                input = data.phasedUnit;
            };
            value offset
                    = correctionUtil.getBeforeParenthesisNode(decNode)
                .endIndex
                .intValue();
            change.addEdit(InsertEdit {
                start = offset;
                text = "()";
            });

            data.addQuickFix {
                description = "Add '()' empty parameter list to "
                + correctionUtil.getDescription(dec);
                change = change;
                selection = DefaultRegion(offset + 1, 0);
            };
        } else {
            platformUtils.log(Status._WARNING,
                "data.node (``
                data.node.nodeType else "<null>"
                ``) is not a Tree.Declaration");
        }
    }

    shared void addImportWildcardProposal(QuickFixData data) {
        if (is Tree.ImportMemberOrTypeList node = data.node) {
            value imtl = node;
            value change 
                    = platformServices.document.createTextChange {
                name = "Add Import Wildcard";
                input = data.phasedUnit;
            };
            value offset = imtl.startIndex.intValue();
            value length = imtl.distance.intValue();
            change.addEdit(ReplaceEdit {
                start = offset;
                length = length;
                text = "{ ... }";
            });
            
            data.addQuickFix {
                description = "Add '...' import wildcard";
                change = change;
                selection = DefaultRegion(offset + 2, 3);
            };
        }
    }

}