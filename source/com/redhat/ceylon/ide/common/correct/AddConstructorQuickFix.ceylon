import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import java.util {
    Collections
}
import com.redhat.ceylon.model.typechecker.model {
    Type
}
shared interface AddConstructorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        DefaultRegion region);
    
    shared void addConstructorProposal(Data data, IFile file) {
        variable Node? node = data.node;
        if (is Tree.TypedDeclaration n = node) {
            node = nodes.findDeclarationWithBody(data.rootNode, n);
        }
        
        if (is Tree.ClassDefinition cd = node) {
            value change = newTextChange("Add Default Constructor", file);
            if (cd.parameterList exists) {
                return;
            }
            
            if (exists body = cd.classBody, cd.identifier exists) {
                value doc = getDocumentForChange(change);
                value uninitialized = correctionUtil.collectUninitializedMembers(body);
                value les = findLastExecutable(body);
                value defaultIndent = indents.defaultIndent;
                value delim = indents.getDefaultLineDelimiter(doc);
                value indent = if (!exists les)
                               then indents.getIndent(cd, doc) + defaultIndent
                               else indents.getIndent(les, doc);
                value unit = cd.unit;
                value params = StringBuilder();
                value initializers = StringBuilder();
                if (!uninitialized.empty) {
                    initializers.append(delim);
                }
                
                for (dec in uninitialized) {
                    if (params.size != 0) {
                        params.append(", ");
                    }
                    
                    value pr = dec.appliedReference(null, Collections.emptyList<Type>());
                    value type = pr.fullType.asString(unit);
                    value name = dec.name;
                    params.append(type).append(" ").append(name);
                    initializers.append(indent).append(defaultIndent).append("this.").append(name).append(" = ").append(name).append(";").append(delim);
                }
                
                if (!uninitialized.empty) {
                    initializers.append(indent);
                }
                
                variable value text = delim + indent + "shared new (" 
                        + params.string + ") {" + initializers.string + "}";
                Integer start;
                if (!exists les) {
                    start = body.startIndex.intValue() + 1;
                    if (body.endIndex.intValue()-1 == start) {
                        text += delim + indents.getIndent(cd, doc);
                    }
                } else {
                    start = les.endIndex.intValue();
                }
                
                addEditToChange(change, newInsertEdit(start, text));
                value firstParen = text.firstOccurrence('(') else 0; 
                value loc = start + firstParen + 1;
                value name = cd.declarationModel.name;
                
                newProposal(data, 
                    "Add constructor 'new (" + params.string + ")' of '" + name + "'",
                    change, DefaultRegion(loc, 0));
            }
        }
    }

    Tree.Statement? findLastExecutable(Tree.ClassBody? body) {
        variable Tree.Statement? les = null;
        if (exists body) {
            value statements = body.statements;
            for (st in statements) {
                if (isExecutableStatement(st) || st is Tree.Constructor) {
                    les = st;
                }
            }
        }
        
        return les;
    }

    Boolean isExecutableStatement(Tree.Statement s) {
        value unit = s.unit;
        if (is Tree.SpecifierStatement s) {
            //shortcut refinement statements with => aren't really "executable"
            value ss = s;
            return !(ss.specifierExpression is Tree.LazySpecifierExpression && !ss.refinement);
        } else if (is Tree.ExecutableStatement s) {
            return true;
        } else {
            if (is Tree.AttributeDeclaration s) {
                value ad = s;
                value sie = ad.specifierOrInitializerExpression;
                return !(sie is Tree.LazySpecifierExpression) && !ad.declarationModel.formal;
            } else if (is Tree.MethodDeclaration s) {
                value ad = s;
                value sie = ad.specifierExpression;
                return !(sie is Tree.LazySpecifierExpression) && !ad.declarationModel.formal;
            } else if (is Tree.ObjectDefinition s) {
                value o = s;
                if (o.extendedType exists) {
                    if (exists et = o.extendedType.type.typeModel,
                        !et.declaration.equals(unit.objectDeclaration), !et.declaration.equals(unit.basicDeclaration)) {
                        return true;
                    }
                }
                
                if (exists ocb = o.classBody) {
                    value statements = ocb.statements;
                    variable value i = statements.size() - 1;
                    while (i >= 0) {
                        value st = statements.get(i);
                        if (isExecutableStatement(st) || st is Tree.Constructor) {
                            return true;
                        }
                        
                        i--;
                    }
                    
                    return false;
                }
                
                return false;
            } else {
                return false;
            }
        }
    }

}
