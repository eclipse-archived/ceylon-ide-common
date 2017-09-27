import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit,
    InsertEdit,
    ReplaceEdit,
    TextChange
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.model.typechecker.model {
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
    
    function parameterList(Tree.Declaration container) {
        switch (container)
        case (is Tree.ClassDefinition) {
            if (exists pl = container.parameterList) {
                return pl;
            }
        }
        case (is Tree.MethodDefinition) {
            value pls = container.parameterLists;
            if (!pls.empty) {
                return pls.get(0);
            }
        }
        case (is Tree.Constructor) {
            if (exists pl = container.parameterList) {
                return pl;
            }
        }
        else {}
        return null;
    }
    
    function definition(Tree.SpecifierOrInitializerExpression? sie, 
        QuickFixData data, TextChange change, FunctionOrValue dec, 
        Tree.TypedDeclaration decNode, String? params, 
        Tree.ParameterList paramList) {
        
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
            def = (decNode is Tree.MethodDeclaration then " => " else " = ")
                    + defaultValue;
        }
        
        String defWithParams 
                    = if (exists params) 
                    then " = " + params + def 
                    else def;
        value param 
                    = (paramList.parameters.empty then "" else ", ") 
                    + dec.name 
                    + defWithParams;
        
        return [len, param];
    }
    
    function returnType(Tree.TypedDeclaration decNode, 
        QuickFixData data, TextChange change) {
        Integer shift;
        Type? paramType;
        value type = decNode.type;
        if (is Tree.LocalModifier type) {
            Type explicitType;
            if (exists inferredType = type.typeModel) {
                explicitType = inferredType;
                value importProposals 
                        = CommonImportProposals {
                    document = data.document;
                    rootNode = data.rootNode;
                };
                importProposals.importType(explicitType);
                shift = importProposals.apply(change);
            }
            else {
                explicitType = type.unit.objectType;
                shift = 0;
            }
            paramType = explicitType;
            
            change.addEdit(ReplaceEdit {
                start = type.startIndex.intValue();
                length = type.text.size;
                text = explicitType.asSourceCodeString(type.unit);
            });
        }
        else {
            paramType = type.typeModel;
            shift = 0;
        }
        return [shift, paramType];
    }
    
    void addParameterProposal(QuickFixData data, 
        Tree.TypedDeclaration decNode, 
        Tree.SpecifierOrInitializerExpression? sie) {
        
        if (is FunctionOrValue dec = decNode.declarationModel,
            !dec.parameter && !dec.formal, 
            dec.container is Functional) {
            value change 
                    = platformServices.document.createTextChange {
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
            if (!exists container) {
                return;
            }
            value paramList = parameterList(container);
            if (!exists paramList) {
                return;
            }
            
            value containerDec = container.declarationModel;
            if (containerDec.actual) {
                return;
            }
            
            let ([len, param]
                    = definition {
                sie = sie;
                data = data;
                change = change;
                dec = dec;
                decNode = decNode;
                params = params;
                paramList = paramList;
            });
            value offset = paramList.endIndex.intValue() - 1;
            
            change.addEdit(InsertEdit {
                start = offset;
                text = param;
            });
            
            let ([shift, paramType]
                    = returnType {
                decNode = decNode;
                data = data;
                change = change;
            });
            
            value containerDesc 
                    = if (exists name = containerDec.name) 
                    then " of '``name``'" else "";

            data.addQuickFix {
                description = "Add '``dec.name``' to parameter list``containerDesc``";
                change()
                    => initializerQuickFix.applyWithLinkedMode {
                        sourceDocument = data.document;
                        change = change;
                        selection = DefaultRegion {
                            start = offset + param.size + shift - len;
                            length = len;
                        };
                        type = paramType;
                        unit = dec.unit;
                        scope = dec.scope;
                        exitPos = data.node.endIndex.intValue();
                    };
                affectsOtherUnits = true;
            };
        }
    }

}