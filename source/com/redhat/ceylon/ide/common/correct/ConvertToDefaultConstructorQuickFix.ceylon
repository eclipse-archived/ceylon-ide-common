import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

shared interface ConvertToDefaultConstructorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared void addConvertToDefaultConstructorProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.ClassDefinition cd = statement,
            exists pl = cd.parameterList) {
            
            value change = newTextChange("Convert to Class with Default Constructor", file);
            initMultiEditChange(change);
            value doc = getDocumentForChange(change);
            value indent = indents.getIndent(statement, doc);
            value delim = indents.getDefaultLineDelimiter(doc);
            value defIndent = indents.defaultIndent;
            variable value insertLoc = cd.classBody.startIndex.intValue() + 1;
            value declarations = StringBuilder();
            value assignments = StringBuilder();
            value params = StringBuilder();
            String extend;
            
            if (exists et = cd.extendedType) {
                value text = getDocContent(doc, et.startIndex.intValue(), et.distance.intValue());
                extend = delim + indent + defIndent + defIndent + defIndent + text;
                
                if (exists pal = et.invocationExpression.positionalArgumentList) {
                    addEditToChange(change, 
                        newDeleteEdit(pal.startIndex.intValue(), pal.distance.intValue()));
                }
            } else {
                extend = "";
            }
            
            for (p in pl.parameters) {
                if (is Tree.InitializerParameter p) {
                    value pdn = nodes.findReferencedNode(data.rootNode, 
                        p.parameterModel.model);
                    
                    if (exists pdn) {
                        //the constructor has to come
                        //after the declarations of the
                        //parameters
                        value index = pdn.endIndex.intValue();
                        if (index > insertLoc) {
                            insertLoc = index;
                        }
                    }
                }
                
                value model = p.parameterModel;
                value paramDef = StringBuilder();
                value pname = model.name;
                value unit = cd.unit;
                variable value end = p.endIndex.intValue();
                value start = p.startIndex.intValue();

                if (is Tree.ParameterDeclaration p) {
                    value pd = p;
                    value td = pd.typedDeclaration;
                    value t = td.type;
                    value text = getDocContent(doc, t.startIndex.intValue(), 
                        p.endIndex.intValue() - t.startIndex.intValue());
                    paramDef.append(text);
                    
                    value tdn = pd.typedDeclaration;
                    Tree.SpecifierOrInitializerExpression? se;
                    
                    if (is Tree.AttributeDeclaration tdn) {
                        se = tdn.specifierOrInitializerExpression;
                    } else if (is Tree.MethodDeclaration tdn) {
                        se = tdn.specifierExpression;
                    } else {
                        se = null;
                    }
                    
                    if (exists se) {
                        end = se.startIndex.intValue();
                    }
                } else if (is Tree.InitializerParameter p) {
                    value ip = p;
                    value pt = model.type;
                    paramDef.append(pt.asString(unit)).append(" ").append(pname);
                    value dec = model.model;
                    if (is Function dec) {
                        value run = dec;
                        for (npl in run.parameterLists) {
                            paramDef.append("(");
                            variable Boolean first = true;
                            for (np in npl.parameters) {
                                if (first) {
                                    first = false;
                                } else {
                                    paramDef.append(", ");
                                }
                                
                                value npt = np.type;
                                paramDef.append(npt.asString(unit)).append(" ").append(np.name);
                            }
                            
                            paramDef.append(")");
                        }
                    }
                    
                    if (exists se = ip.specifierExpression) {
                        value text = getDocContent(doc, 
                            se.startIndex.intValue(), se.distance.intValue());
                        paramDef.append(text);
                        
                        end = se.startIndex.intValue();
                    }
                } else {
                    //impossible
                    return;
                }
                
                value attDef = getDocContent(doc, start, end - start).trimmed;
                
                if (is Tree.ParameterDeclaration p) {
                    declarations.append(indent)
                            .append(defIndent)
                            .append(attDef)
                            .append(";")
                            .append(delim);
                }
                
                assignments.append(indent)
                        .append(defIndent)
                        .append(defIndent)
                        .append("this.")
                        .append(pname)
                        .append(" = ")
                        .append(pname)
                        .append(";")
                        .append(delim);
                
                if (params.size > 0) {
                    params.append(", ");
                }
                
                params.append(paramDef.string);
            }
            
            value text = delim + declarations.string + indent + defIndent 
                    + "shared new (" + params.string + ")" + extend + " {"
                    + delim + assignments.string + indent + defIndent + "}"
                    + delim;
            
            addEditToChange(change, newDeleteEdit(pl.startIndex.intValue(), 
                pl.distance.intValue()));
            
            addEditToChange(change, newInsertEdit(insertLoc, text));
            
            value name = cd.declarationModel.name;
            
            newProposal(data, "Convert '" + name + "' to class with default constructor", 
                change, DefaultRegion(cd.startIndex.intValue(), 0));
        }
    }
}
