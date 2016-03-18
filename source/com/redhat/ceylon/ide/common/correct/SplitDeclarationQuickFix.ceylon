import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
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

import java.util {
    HashSet
}

shared interface SplitDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {

    void addSplitDeclarationProposal(Data data, Tree.TypedDeclaration decNode, IFile file) {
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
        value change = newTextChange("Split Declaration", file);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        value typeString = getDocContent(doc, typeStartOffset, typeEndOffset - typeStartOffset);
        
        if (is Tree.MethodDeclaration md = decNode) {
            value pls = md.parameterLists;
            if (pls.empty) {
                return;
            } else {
                value paramsOffset = pls.get(0).startIndex.intValue();
                paramsEndOffset = pls.get(pls.size() - 1).endIndex.intValue();
                paramsString = getDocContent(doc, paramsOffset, paramsEndOffset - paramsOffset);
            }
        }
        
        value delim = indents.getDefaultLineDelimiter(doc);
        value indent = indents.getIndent(decNode, doc);
        if (dec.parameter) {
            addEditToChange(change, newDeleteEdit(startOffset, idStartOffset - startOffset));
            addEditToChange(change, newDeleteEdit(idEndOffset, paramsEndOffset - idEndOffset));

            assert (is Declaration container = dec.container);

            value containerNode = nodes.getReferencedNodeInUnit(container, data.rootNode);
            
            Tree.Body? body;
            if (is Tree.ClassDefinition cd = containerNode) {
                body = cd.classBody;
            } else if (is Tree.MethodDefinition md = containerNode) {
                body = md.block;
            } else if (is Tree.FunctionArgument fa = containerNode) {
                body = fa.block;
            } else if (is Tree.Constructor cd = containerNode) {
                body = cd.block;
            } else {
                return;
            }
            
            if (!exists body) {
                return;
            }
            if (body.statements.contains(decNode)) {
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
                    annotations = getDocContent(doc, alstart, allen) + " ";
                }
            }
            
            variable value text = delim + indent + indents.defaultIndent
                     + annotations + typeString + " " + dec.name + paramsString + ";";
            value bstart = body.startIndex.intValue();
            value bstop = body.endIndex.intValue();
            if (bstop-1 == bstart+1) {
                text += delim+indent;
            }
            
            addEditToChange(change, newInsertEdit(bstart + 1, text));
        } else {
            value text = paramsString + ";" + delim + indent + dec.name;
            addEditToChange(change, newInsertEdit(idEndOffset, text));
        }
        
        variable Integer il;
        if (is Tree.LocalModifier type) {
            variable String explicitType;
            if (exists infType = type.typeModel) {
                explicitType = infType.asSourceCodeString(decNode.unit);
                value decs = HashSet<Declaration>();
                importProposals.importType(decs, infType, data.rootNode);
                il = importProposals.applyImports(change, decs, data.rootNode, doc);
            } else {
                explicitType = "Object";
                il = 0;
            }
            
            value typeOffset = type.startIndex.intValue();
            value typeLen = type.distance.intValue();
            addEditToChange(change, newReplaceEdit(typeOffset, typeLen, explicitType));
        } else {
            il = 0;
        }
        
        value desc = "Split declaration of '" + dec.name + "'";
        newProposal(data, desc, change, DefaultRegion(idEndOffset + il, 0));
    }
    
    shared void addSplitDeclarationProposals(Data data, IFile file, 
        Tree.Declaration? decNode, Tree.Statement? statement) {
        
        if (!exists decNode) {
            return;
        }
        
        if (exists dec = decNode.declarationModel) {
            if (is Tree.AttributeDeclaration decNode) {
                value attDecNode = decNode;
                if (attDecNode.specifierOrInitializerExpression exists || dec.parameter) {
                    addSplitDeclarationProposal(data, attDecNode, file);
                }
            }
            
            if (is Tree.MethodDeclaration decNode) {
                value methDecNode = decNode;
                if (methDecNode.specifierExpression exists
                    then !dec.parameter else dec.parameter) {
                    addSplitDeclarationProposal(data, methDecNode, file);
                }
            }
            
            if (is Tree.Variable decNode,
                is Tree.ControlStatement statement,
                exists sie = decNode.specifierExpression) {
                
                addSplitDeclarationProposal2(data, decNode, statement, file);
            }
        }
    }
    
    void addSplitDeclarationProposal2(Data data, Tree.Variable varNode, 
        Tree.ControlStatement statement, IFile file) {
        
        if (exists sie = varNode.specifierExpression,
            exists id = varNode.identifier,
            !(varNode.type is Tree.SyntheticVariable)) {
            
            value tfc = newTextChange("Split Variable", file);
            initMultiEditChange(tfc);
            value vstart = varNode.startIndex.intValue();
            value vlen = varNode.distance.intValue();
            value doc = getDocumentForChange(tfc);
            value text = "value " + getDocContent(doc, vstart, vlen) + ";"
                    + indents.getDefaultLineDelimiter(doc)
                    + indents.getIndent(statement, doc);
            
            value start = statement.startIndex.intValue();
            addEditToChange(tfc, newInsertEdit(start, text));
            value estart = id.endIndex.intValue();
            value eend = sie.endIndex.intValue();
            
            addEditToChange(tfc, newDeleteEdit(estart, eend - estart));
            
            value desc = "Split declaration of '" + varNode.declarationModel.name + "'";

            newProposal(data, desc, tfc, DefaultRegion(start + 6, 0));
        }
    }
}
