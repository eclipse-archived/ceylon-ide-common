import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

shared object convertToDefaultConstructorQuickFix {
    
    shared void addConvertToDefaultConstructorProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.ClassDefinition statement,
            exists pl = statement.parameterList) {
            
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Class with Default Constructor";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value doc = change.document;
            value indent = doc.getIndent(statement);
            value delim = doc.defaultLineDelimiter;
            value defIndent = platformServices.document.defaultIndent;
            value declarations = StringBuilder();
            value assignments = StringBuilder();
            value params = StringBuilder();
            String extend;
            
            if (exists et = statement.extendedType) {
                value text = doc.getText {
                    offset = et.startIndex.intValue();
                    length = et.distance.intValue();
                };
                extend = delim + indent + defIndent + defIndent + defIndent + text;
                
                if (exists pal = et.invocationExpression?.positionalArgumentList) {
                    change.addEdit(DeleteEdit {
                        start = pal.startIndex.intValue();
                        length = pal.distance.intValue();
                    });
                }
            }
            else {
                extend = "";
            }
            
            variable Integer insertLoc 
                    = statement.classBody.startIndex.intValue() + 1;
            for (p in pl.parameters) {
                if (is Tree.InitializerParameter p, 
                    exists pdn = nodes.findReferencedNode {
                        cu = data.rootNode;
                        model = p.parameterModel.model;
                    }) {
                    //the constructor has to come
                    //after the declarations of the
                    //parameters
                    value index = pdn.endIndex.intValue();
                    if (index > insertLoc) {
                        insertLoc = index;
                    }
                }
                
                value model = p.parameterModel;
                value paramDef = StringBuilder();
                String? pname = model.name;
                if (!exists pname) {
                    return;
                }
                value unit = statement.unit;
                Integer end;
                value start = p.startIndex.intValue();
                
                switch (p)
                case (is Tree.ParameterDeclaration) {
                    value pd = p;
                    value td = pd.typedDeclaration;
                    value t = td.type;
                    value text = doc.getText {
                        offset = t.startIndex.intValue();
                        length = p.endIndex.intValue() 
                                - t.startIndex.intValue();
                    };
                    paramDef.append(text);
                    
                    Tree.SpecifierOrInitializerExpression? se;                    
                    switch (tdn = pd.typedDeclaration)
                    case (is Tree.AttributeDeclaration) {
                        se = tdn.specifierOrInitializerExpression;
                    }
                    case (is Tree.MethodDeclaration) {
                        se = tdn.specifierExpression;
                    }
                    else {
                        se = null;
                    }
                    
                    if (exists se) {
                        end = se.startIndex.intValue();
                    }
                    else {
                        end = p.endIndex.intValue();
                    }
                }
                case (is Tree.InitializerParameter) {
                    value ip = p;
                    value pt = model.type;
                    paramDef.append(pt.asString(unit))
                            .append(" ")
                            .append(pname);
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
                                paramDef.append(npt.asString(unit))
                                        .append(" ")
                                        .append(np.name);
                            }
                            
                            paramDef.append(")");
                        }
                    }
                    
                    if (exists se = ip.specifierExpression) {
                        value text = doc.getText {
                            offset = se.startIndex.intValue();
                            length = se.distance.intValue();
                        };
                        paramDef.append(text);
                        end = se.startIndex.intValue();
                    }
                    else {
                        end = p.endIndex.intValue();
                    }
                } else {
                    //impossible
                    return;
                }
                                
                if (is Tree.ParameterDeclaration p) {
                    value attDef = doc.getText(start, end-start).trimmed;
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
            
            change.addEdit(DeleteEdit(pl.startIndex.intValue(), 
                pl.distance.intValue()));
            
            change.addEdit(InsertEdit {
                start = insertLoc;
                text 
                    = delim + declarations.string + indent + defIndent
                    + "shared new (``params``)``extend`` {``delim````assignments````indent+defIndent``}"
                    + delim;
            });
            
            data.addQuickFix {
                description = "Convert '``statement.declarationModel.name``' to class with default constructor";
                change = change;
                selection = DefaultRegion(statement.startIndex.intValue());
            };
        }
    }
}
