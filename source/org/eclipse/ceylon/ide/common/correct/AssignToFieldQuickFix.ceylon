import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.model.typechecker.model {
    FunctionOrValue
}

shared object assignToFieldQuickFix {
    
    shared void addAssignToFieldProposal(QuickFixData data, 
        Tree.Statement? statement, Tree.Declaration? declaration) {
        
        if (is Tree.TypedDeclaration declaration, 
            is Tree.Constructor statement) {
            value constructor = statement;
            value param = declaration;
            value model = param.declarationModel;
            value name = model.name;
            value cmodel = constructor.constructor;
            
            if (!model.container.equals(cmodel)) {
                return;
            }
            
            value clazz = cmodel.extendedType.declaration;
            value existing = clazz.getMember(name, null, false);
            
            if (!exists existing) {
                //ok, continue
            } else if (is FunctionOrValue fov = existing) {
                value type = fov.typedReference.fullType;
                value paramType = model.typedReference.fullType;
                
                if (!exists type) {
                    return;
                }
                if (!exists paramType) {
                    return;
                }
                if (!paramType.isSubtypeOf(type)) {
                    return;
                }
            } else {
                return;
            }
            
            value change 
                    = platformServices.document.createTextChange {
                name = "Assign to Field";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value document = change.document;
            value indent 
                    = document.defaultLineDelimiter 
                    + document.getIndent(constructor);
            
            String desc;
            if (!exists existing) {
                Tree.SpecifierOrInitializerExpression? sie;
                switch (declaration)
                case (is Tree.AttributeDeclaration) {
                    sie = declaration.specifierOrInitializerExpression;
                }
                case (is Tree.MethodDeclaration) {
                    sie = declaration.specifierExpression;
                }
                else {
                    sie = null;
                }
                
                value start = declaration.startIndex.intValue();
                value end = if (!exists sie) 
                            then declaration.endIndex.intValue() 
                            else sie.startIndex.intValue();
                
                change.addEdit(InsertEdit {
                    start = statement.startIndex.intValue();
                    text 
                        = document.getText(start, end-start).trimmed
                        + ";" + indent;
                });
                desc = "Assign parameter '``name``' to new field of '``clazz.name``'";
            }
            else {
                desc = "Assign parameter '``name``' to field '``name``' of '``clazz.name``'";
            }
            change.addEdit(InsertEdit {
                start = constructor.block.startIndex.intValue() + 1;
                text 
                    = indent 
                    + platformServices.document.defaultIndent 
                    + "this.``name`` = ``name``;";
            });
            
            data.addQuickFix(desc, change);
        }
    }
}
