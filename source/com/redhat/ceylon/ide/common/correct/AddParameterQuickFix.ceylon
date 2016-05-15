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
    FunctionOrValue,
    Functional,
    Type
}

shared object addParameterQuickFix {
    
    shared void addParameterProposals(QuickFixData data) {
        switch (node = data.node)
        case (is Tree.AttributeDeclaration) {
            Tree.SpecifierOrInitializerExpression? sie 
                    = node.specifierOrInitializerExpression;
            if (!(sie is Tree.LazySpecifierExpression)) {
                addParameterProposal(data, node, sie);
            }
        }
        case (is Tree.MethodDeclaration) {
            addParameterProposal(data, node, 
                node.specifierExpression);
        }
        else {}
    }

    void addParameterProposal(QuickFixData data, 
        Tree.TypedDeclaration decNode, 
        Tree.SpecifierOrInitializerExpression? sie) {
        
        if (is FunctionOrValue dec = decNode.declarationModel,
            !dec.parameter && !dec.formal, 
            dec.container is Functional) {
            value change 
                    = platformServices.createTextChange {
                name = "Add Parameter";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            //TODO: copy/pasted from SplitDeclarationProposal 
            String? params;
            if (is Tree.MethodDeclaration decNode) {
                value pls = decNode.parameterLists;
                if (pls.empty) {
                    return;
                }
                else {
                    value start 
                            = pls.get(0)
                                .startIndex
                                .intValue();
                    value end 
                            = pls.get(pls.size()-1)
                                .endIndex
                                .intValue();
                    params = data.document.getText {
                        offset = start;
                        length = end-start;
                    };
                }
            }
            else {
                params = null;
            }
            
            value container 
                    = nodes.findDeclarationWithBody {
                cu = data.rootNode;
                node = decNode;
            };
            
            Tree.ParameterList paramList;
            switch (container)
            case (is Tree.ClassDefinition) {
                if (exists pl = container.parameterList) {
                    paramList = pl;
                }
                else {
                    return;
                }
            }
            case (is Tree.MethodDefinition) {
                value pls = container.parameterLists;
                if (pls.empty) {
                    return;
                }
                paramList = pls.get(0);
            }
            case (is Tree.Constructor) {
                if (exists pl = container.parameterList) {
                    paramList = pl;
                }
                else {
                    return;
                }
            }
            else {
                return;
            }
            assert (exists container);
            value cont = container.declarationModel;
            if (cont.actual) {
                return;
            }
            
            String def;
            Integer len;
            if (exists sie) {
                len = 0;
                value text = data.document.getText {
                    offset = sie.startIndex.intValue();
                    length = sie.distance.intValue();
                };
                value start = sie.startIndex.intValue();
                Integer realStart;
                if (start > 0, 
                    data.document.getText(start-1, 1)==" ") {
                    realStart = start-1;
                    def = " " + text;
                }
                else {
                    realStart = start;
                    def = text;
                }
                
                change.addEdit(DeleteEdit {
                    start = realStart;
                    length = sie.endIndex.intValue() - realStart;
                });
            }
            else {
                value defaultValue 
                        = correctionUtil.defaultValue {
                            unit = data.rootNode.unit;
                            type = dec.type;
                        };
                len = defaultValue.size;
                def = (if (is Tree.MethodDeclaration decNode) 
                        then " => " else " = ") 
                    + defaultValue;
            }
            
            String defWithParams 
                    = if (exists params) 
                    then " = " + params + def 
                    else def;
            
            value param 
                    = (if (paramList.parameters.empty) then "" else ", ") 
                    + dec.name 
                    + defWithParams;
            value offset = paramList.endIndex.intValue() - 1;
            
            change.addEdit(InsertEdit {
                start = offset;
                text = param;
            });
            value type = decNode.type;
            Integer shift;
            Type? paramType;
            if (is Tree.LocalModifier type) {
                String explicitType;
                if (exists pt = type.typeModel) {
                    paramType = pt;
                    explicitType 
                            = pt.asSourceCodeString(type.unit);
                    value importProposals 
                            = CommonImportProposals {
                        document = data.document;
                        rootNode = data.rootNode;
                    };
                    importProposals.importedType(paramType);
                    shift = importProposals.apply(change);
                }
                else {
                    explicitType = "Object";
                    paramType = type.unit.objectType;
                    shift = 0;
                }
                
                change.addEdit(ReplaceEdit {
                    start = type.startIndex.intValue();
                    length = type.text.size;
                    text = explicitType;
                });
            } else {
                paramType = type.typeModel;
                shift = 0;
            }
            
            variable String desc = "Add '``dec.name``' to parameter list";
            if (exists name = cont.name) {
                desc += " of '``name``'";
            }
            
            data.addParameterQuickFix {
                desc = desc;
                change = change;
                selection = DefaultRegion {
                    start = offset + param.size + shift - len;
                    length = len;
                };
                unit = cont.unit;
                scope = cont.scope;
                type = paramType;
                exitPos = data.node.endIndex.intValue();
            };
        }
    }

}