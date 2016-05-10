import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue,
    Functional,
    Type,
    Declaration
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import java.util {
    HashSet
}

shared interface AddParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, Declaration dec, 
        Type? type, Integer offset, Integer length, TextChange change, 
        Integer exitPos);
    
    shared void addParameterProposals(Data data, IFile file) {
        if (is Tree.AttributeDeclaration attDecNode = data.node) {
            Tree.SpecifierOrInitializerExpression? sie = attDecNode.specifierOrInitializerExpression;
            if (!(sie is Tree.LazySpecifierExpression)) {
                addParameterProposal(data, file, attDecNode, sie);
            }
        }
        
        if (is Tree.MethodDeclaration node = data.node) {
            value methDecNode = node;
            Tree.SpecifierOrInitializerExpression? sie = methDecNode.specifierExpression;
            addParameterProposal(data, file, methDecNode, sie);
        }
    }

    void addParameterProposal(Data data, IFile file, Tree.TypedDeclaration decNode, Tree.SpecifierOrInitializerExpression? sie) {
        assert (is FunctionOrValue? dec = decNode.declarationModel);
        if (!exists dec) {
            return;
        }
        
        if (!dec.initializerParameter exists, !dec.formal, dec.container is Functional) {
            value change = newTextChange("Add Parameter", file);
            initMultiEditChange(change);
            value doc = getDocumentForChange(change);
            //TODO: copy/pasted from SplitDeclarationProposal 
            variable String? params = null;
            if (is Tree.MethodDeclaration decNode) {
                value md = decNode;
                value pls = md.parameterLists;
                if (pls.empty) {
                    return;
                } else {
                    value start = pls.get(0).startIndex.intValue();
                    value end = pls.get(pls.size() - 1).endIndex.intValue();

                    
                    params = getDocContent(doc, start, end - start);
                }
            }
            
            value container = nodes.findDeclarationWithBody(data.rootNode, decNode);
            variable Tree.ParameterList? pl;
            if (is Tree.ClassDefinition container) {
                value cd = container;
                pl = cd.parameterList;
                if (!exists _ = pl) {
                    return;
                }
            } else if (is Tree.MethodDefinition container) {
                value md = container;
                value pls = md.parameterLists;
                if (pls.empty) {
                    return;
                }
                
                pl = pls.get(0);
            } else if (is Tree.Constructor container) {
                value cd = container;
                pl = cd.parameterList;
                if (!exists _ = pl) {
                    return;
                }
            } else {
                return;
            }
            
            variable String def;
            variable Integer len;
            if (!exists sie) {
                value defaultValue = correctionUtil.defaultValue(data.rootNode.unit, dec.type);
                len = defaultValue.size;
                if (is Tree.MethodDeclaration decNode) {
                    def = " => " + defaultValue;
                } else {
                    def = " = " + defaultValue;
                }
            } else {
                len = 0;
                def = getDocContent(doc, sie.startIndex.intValue(), sie.distance.intValue());
                variable Integer start = sie.startIndex.intValue();
                if (start > 0, getDocContent(doc, start - 1, 1).equals(" ")) {
                    start--;
                    def = " " + def;
                }
                
                addEditToChange(change, newDeleteEdit(start, sie.endIndex.intValue() - start));
            }
            
            if (exists p = params) {
                def = " = " + p + def;
            }
            
            assert(exists _pl = pl);
            value param = (if (_pl.parameters.empty) then "" else ", ") + dec.name + def;
            value offset = _pl.endIndex.intValue() - 1;
            addEditToChange(change, newInsertEdit(offset, param));
            value type = decNode.type;
            variable Integer shift = 0;
            variable Type? paramType;
            if (is Tree.LocalModifier type) {
                value typeOffset = type.startIndex.intValue();
                paramType = type.typeModel;
                variable String explicitType;
                if (!exists pt = paramType) {
                    explicitType = "Object";
                    paramType = type.unit.objectType;
                } else {
                    assert(exists pt = paramType);
                    explicitType = pt.asString();
                    value decs = HashSet<Declaration>();
                    importProposals.importType(decs, paramType, data.rootNode);
                    shift = importProposals.applyImports(change, decs, data.rootNode, doc);
                }
                
                addEditToChange(change, newReplaceEdit(typeOffset, type.text.size, explicitType));
            } else {
                paramType = type.typeModel;
            }
            
            value exitPos = data.node.endIndex.intValue();
            variable String desc = "Add '" + dec.name + "' to parameter list";
            assert(exists container);
            value cont = container.declarationModel;
            if (cont.name exists) {
                desc += " of '"+cont.name+"'";
            }
            
            newProposal(data, desc, cont, paramType, 
                offset + param.size + shift - len, len, change, exitPos);
        }
    }

}