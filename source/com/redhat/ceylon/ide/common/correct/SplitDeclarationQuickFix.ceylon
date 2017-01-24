import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit,
    InsertEdit,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    TypedDeclaration,
    Declaration
}

shared object splitDeclarationQuickFix {

    void addSplitDeclarationProposal(QuickFixData data, 
        Tree.TypedDeclaration decNode) {
        
        TypedDeclaration? dec = decNode.declarationModel;
        if (!exists dec) {
            return;
        }
        
        if (dec.toplevel) {
            return;
        }
        
        Tree.Identifier? id = decNode.identifier;
        if (!exists id) {
            return;
        }
        if (!id.token exists) {
            return;
        }
        
        value idStartOffset = id.startIndex.intValue();
        value idEndOffset = id.endIndex.intValue();
        value startOffset = decNode.startIndex.intValue();
        variable value paramsEndOffset = idEndOffset;
        variable value paramsString = "";
        Tree.Type? type = decNode.type;
        if (!exists type) {
            return;
        }
        if (!type.token exists) {
            return;
        }
        
        value typeStartOffset = type.startIndex.intValue();
        value typeEndOffset = type.endIndex.intValue();
        value change 
                = platformServices.document.createTextChange {
            name = "Split Declaration";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        value doc = change.document;
        value typeString = doc.getText {
            offset = typeStartOffset;
            length = typeEndOffset - typeStartOffset;
        };
        
        if (is Tree.MethodDeclaration md = decNode) {
            value pls = md.parameterLists;
            if (pls.empty) {
                return;
            } else {
                value paramsOffset = pls.get(0).startIndex.intValue();
                paramsEndOffset = pls.get(pls.size() - 1).endIndex.intValue();
                paramsString = doc.getText {
                    offset = paramsOffset;
                    length = paramsEndOffset - paramsOffset;
                };
            }
        }
        
        value delim = doc.defaultLineDelimiter;
        value indent = doc.getIndent(decNode);
        if (dec.parameter,
            is Declaration container = dec.container) {

            change.addEdit(DeleteEdit {
                start = startOffset;
                length = idStartOffset - startOffset;
            });
            change.addEdit(DeleteEdit {
                start = idEndOffset;
                length = paramsEndOffset - idEndOffset;
            });

            // Specifier expressions should be split to `name = (params) => expression`
            // instead of `name => expression`
            if (is Tree.MethodDeclaration md = decNode,
                md.specifierExpression exists) {
                change.addEdit(InsertEdit {
                    start = idEndOffset;
                    text = " = ``paramsString``";
                });
            }

            value containerNode 
                    = nodes.getReferencedNode { 
                        model = container; 
                        rootNode = data.rootNode; 
                    };
            
            Tree.Body? body;
            switch (containerNode)
            case (is Tree.ClassDefinition) {
                body = containerNode.classBody;
            }
            case (is Tree.MethodDefinition) {
                body = containerNode.block;
            }
            case (is Tree.FunctionArgument) {
                body = containerNode.block;
            }
            case (is Tree.Constructor) {
                body = containerNode.block;
            }
            else {
                return;
            }
            
            if (!exists body) {
                return;
            }
            if (decNode in body.statements) {
                return;
            }
            
            Tree.AnnotationList? al = decNode.annotationList;
            String annotations;
            if (!exists al) {
                annotations = "";
            } else if (!al.token exists) {
                annotations = "";
            } else {
                value alstart = al.startIndex.intValue();
                value allen = al.distance.intValue();
                if (allen == 0) {
                    annotations = "";
                } else {
                    annotations = doc.getText(alstart, allen) + " ";
                }
            }
            
            variable value text = delim + indent + platformServices.document.defaultIndent
                     + annotations + typeString + " " + dec.name + paramsString + ";";
            value bstart = body.startIndex.intValue();
            value bstop = body.endIndex.intValue();
            if (bstop-1 == bstart+1) {
                text += delim+indent;
            }
            
            change.addEdit(InsertEdit(bstart + 1, text));
        } else {
            value text = paramsString + ";" + delim + indent + dec.name;
            change.addEdit(InsertEdit(idEndOffset, text));
        }
        
        variable Integer il;
        if (is Tree.LocalModifier type) {
            variable String explicitType;
            if (exists infType = type.typeModel, !infType.unknown) {
                explicitType = infType.asSourceCodeString(decNode.unit);
                value importProposals 
                        = CommonImportProposals(doc, data.rootNode);
                importProposals.importType(infType);
                il = importProposals.apply(change);
            } else {
                explicitType = "Object";
                il = 0;
            }
            
            value typeOffset = type.startIndex.intValue();
            value typeLen = type.distance.intValue();
            change.addEdit(ReplaceEdit(typeOffset, typeLen, explicitType));
        } else {
            il = 0;
        }
        data.addQuickFix {
            description = "Split declaration of '``dec.name``'";
            change = change;
            selection = DefaultRegion(idEndOffset + il, 0);
        };
    }
    
    shared void addSplitDeclarationProposals(QuickFixData data,
        Tree.Declaration? decNode, Tree.Statement? statement) {
        
        if (exists decNode, 
            exists dec = decNode.declarationModel, 
            !dec.toplevel) {
            switch (decNode)
            case (is Tree.AttributeDeclaration) {
                if (decNode.specifierOrInitializerExpression exists || dec.parameter) {
                    addSplitDeclarationProposal(data, decNode);
                }
            }
            case (is Tree.MethodDeclaration) {
                if (decNode.specifierExpression exists || dec.parameter) {
                    addSplitDeclarationProposal(data, decNode);
                }
            }
            case (is Tree.Variable) {
                if (is Tree.ControlStatement statement,
                    exists sie = decNode.specifierExpression) {
                    addSplitDeclarationProposal2(data, decNode, statement);
                }
            }
            else {}
        }
    }
    
    void addSplitDeclarationProposal2(QuickFixData data, 
        Tree.Variable varNode, 
        Tree.ControlStatement statement) {
        
        if (exists sie = varNode.specifierExpression,
            exists id = varNode.identifier,
            !(varNode.type is Tree.SyntheticVariable)) {
            
            value change = platformServices.document.createTextChange {
                name = "Split Variable";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value vstart = varNode.startIndex.intValue();
            value vlen = varNode.distance.intValue();
            value doc = change.document;
            value text = "value " + doc.getText(vstart, vlen) + ";"
                    + doc.defaultLineDelimiter
                    + doc.getIndent(statement);
            
            value start = statement.startIndex.intValue();
            change.addEdit(InsertEdit(start, text));
            value estart = id.endIndex.intValue();
            value eend = sie.endIndex.intValue();
            
            change.addEdit(DeleteEdit(estart, eend - estart));

            data.addQuickFix {
                description = "Split declaration of '``varNode.declarationModel.name``'";
                change = change;
                selection = DefaultRegion(start + 6);
            };
        }
    }
}
