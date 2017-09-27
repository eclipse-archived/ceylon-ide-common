import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    DeleteEdit
}
import org.eclipse.ceylon.model.typechecker.model {
    ModelUtil,
    Value,
    ClassOrInterface
}

shared object addStaticImportQuickFix {

    shared void addProposal(QuickFixData data) {
        if (is Tree.QualifiedMemberOrTypeExpression qmte = data.node) {
            value prim = qmte.primary;
            if (is Tree.BaseMemberExpression prim,
                is Value dec = prim.declaration,
                dec.toplevel && ModelUtil.isObject(dec),
                exists importNode =
                        importProposals.findImportNode {
                            rootNode = data.rootNode;
                            packageName = dec.unit.\ipackage.nameAsString;
                            scope = qmte.scope;
                        },
                exists imtl = importNode.importMemberOrTypeList) {
                for (imt in imtl.importMemberOrTypes) {
                    if (exists id = imt.declarationModel,
                        id.name == dec.name) {
                        addStaticImportProposal {
                            data = data;
                            imt = imt;
                            id = qmte.identifier;
                            primary = prim;
                        };
                    }
                }
            }
            else if (is Tree.BaseTypeExpression prim,
                prim.typeArguments is Tree.InferredTypeArguments?,
                is ClassOrInterface dec = prim.declaration,
                dec.toplevel,
                exists importNode =
                        importProposals.findImportNode {
                            rootNode = data.rootNode;
                            packageName = dec.unit.\ipackage.nameAsString;
                            scope = qmte.scope;
                        },
                exists imtl = importNode.importMemberOrTypeList) {
                for (imt in imtl.importMemberOrTypes) {
                    if (exists id = imt.declarationModel,
                        id.name == dec.name) {
                        addStaticImportProposal {
                            data = data;
                            imt = imt;
                            id = qmte.identifier;
                            primary = prim;
                        };
                    }
                }
            }
        }
    }

    void addStaticImportProposal(QuickFixData data,
            Tree.ImportMemberOrType imt, Tree.Identifier id,
            Tree.Primary primary) {
        value change
                = platformServices.document.createTextChange {
            name = "Add Static Import";
            input = data.phasedUnit;
        };
        value doc = change.document;
        change.initMultiEdit();

        value name = doc.getNodeText(id);
        value indent = doc.getIndent(imt);
        value extra = platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        value imtl = imt.importMemberOrTypeList;

        variable value alreadyImported = false;
        if (exists ms = imtl?.importMemberOrTypes) {
            for (m in ms) {
                if (doc.getNodeText(m.identifier) == name) {
                    alreadyImported = true;
                    break;
                }
            }
        }

        if (!alreadyImported) {
            change.addEdit(InsertEdit {
                start =
                    if (exists imtl)
                    then importProposals.getBestImportMemberInsertPosition(imt)
                    else imt.endIndex.intValue();
                text =
                    if (exists imtl)
                    then "," + delim + indent + extra + name
                    else " {" + delim + indent + extra + name + delim + indent + "}";
            });
        }

        change.addEdit(DeleteEdit {
            start = primary.startIndex.intValue();
            length = id.startIndex.intValue() - primary.startIndex.intValue();
        });

        data.addQuickFix {
            description = "Add static import for '``id.text``'";
            change = change;
//            selection = DefaultRegion(loc);
        };
    }


}