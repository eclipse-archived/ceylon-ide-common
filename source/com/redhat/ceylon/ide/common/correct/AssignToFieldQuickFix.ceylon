import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue,
    Declaration,
    Type
}

shared interface AssignToFieldQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addAssignToFieldProposal(Data data, IFile file, 
        Tree.Statement? statement, Tree.Declaration? declaration) {
        
        if (is Tree.TypedDeclaration declaration, is Tree.Constructor statement) {
            value constructor = statement;
            value param = declaration;
            value model = param.declarationModel;
            value name = model.name;
            value cmodel = constructor.constructor;
            
            if (!model.container.equals(cmodel)) {
                return;
            }
            
            value clazz = cmodel.extendedType.declaration;
            Declaration? existing = clazz.getMember(name, null, false);
            
            if (!exists existing) {
                //ok, continue
            } else if (is FunctionOrValue fov = existing) {
                Type? type = fov.typedReference.fullType;
                Type? paramType = model.typedReference.fullType;
                
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
            
            value change = newTextChange("Assign to Field", file);
            initMultiEditChange(change);
            value document = getDocumentForChange(change);
            value indent = indents.getDefaultLineDelimiter(document) 
                    + indents.getIndent(constructor, document);
            
            String desc;
            if (!exists existing) {
                value start = declaration.startIndex.intValue();
                Tree.SpecifierOrInitializerExpression? sie;
                if (is Tree.AttributeDeclaration declaration) {
                    value ad = declaration;
                    sie = ad.specifierOrInitializerExpression;
                } else if (is Tree.MethodDeclaration declaration) {
                    value ad = declaration;
                    sie = ad.specifierExpression;
                } else {
                    sie = null;
                }
                
                value end = if (!exists sie) 
                            then declaration.endIndex.intValue() 
                            else sie.startIndex.intValue();
                
                value def = getDocContent(document, start, end - start).trimmed
                    + ";" + indent;
                
                value loc = statement.startIndex.intValue();
                addEditToChange(change, newInsertEdit(loc, def));
                desc = "Assign parameter '" + name + "' to new field of '" + clazz.name + "'";
            } else {
                desc = "Assign parameter '" + name + "' to field '" + name + "' of '" + clazz.name + "'";
            }
            
            value offset = constructor.block.startIndex.intValue() + 1;
            value text = indent + indents.defaultIndent + "this." + name + " = " + name + ";";
            addEditToChange(change, newInsertEdit(offset, text));
            
            newProposal(data, desc, change);
        }
    }
}
