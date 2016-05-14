import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    commonIndents,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type
}

import java.util {
    Collections
}
shared object addConstructorQuickFix {
    
    shared void addConstructorProposal(QuickFixData data) {
        
        if (is Tree.ClassDefinition cd 
                = if (is Tree.TypedDeclaration node = data.node) 
                    then nodes.findDeclarationWithBody(data.rootNode, node) 
                    else data.node) {
            value change 
                    = platformServices.createTextChange {
                desc = "Add Default Constructor";
                input = data.phasedUnit;
            };
            
            if (exists body = cd.classBody, 
                !cd.parameterList exists,
                cd.identifier exists) {
                value doc = data.document;
                value uninitialized 
                        = correctionUtil.collectUninitializedMembers(body);
                value les = findLastExecutable(body);
                value defaultIndent 
                        = commonIndents.defaultIndent;
                value delim 
                        = commonIndents.getDefaultLineDelimiter(doc);
                value indent 
                        = if (!exists les)
                        then commonIndents.getIndent(cd, doc) 
                                + defaultIndent
                        else commonIndents.getIndent(les, doc);
                value unit = cd.unit;
                value params = StringBuilder();
                value initializers = StringBuilder();
                if (!uninitialized.empty) {
                    initializers.append(delim);
                }
                
                for (dec in uninitialized) {
                    if (!params.empty) {
                        params.append(", ");
                    }
                    value type 
                            = dec.appliedReference(null, 
                                    Collections.emptyList<Type>())
                                 .fullType;
                    value name = dec.name;
                    params.append(type.asString(unit))
                          .append(" ")
                          .append(name);
                    initializers.append(indent)
                                .append(defaultIndent)
                                .append("this.")
                                .append(name).append(" = ")
                                .append(name)
                                .append(";")
                                .append(delim);
                }
                
                if (!uninitialized.empty) {
                    initializers.append(indent);
                }
                
                value text = "``delim````indent``shared new (``params``) {``initializers``}";
                Integer start;
                String textWithWs;
                if (exists les) {
                    start = les.endIndex.intValue();
                    textWithWs = text;
                }
                else {
                    start = body.startIndex.intValue() + 1;
                    if (body.endIndex.intValue()-1 == start) {
                        textWithWs 
                                = text + delim 
                                + commonIndents.getIndent(cd, doc);
                    }
                    else {
                        textWithWs = text;
                    }
                }
                
                change.addEdit(InsertEdit {
                    start = start;
                    text = textWithWs;
                });
                value firstParen 
                        = text.firstOccurrence('(') else 0; 
                value loc = start + firstParen + 1;
                value name = cd.declarationModel.name;
                
                data.addQuickFix { 
                    desc = "Add constructor 'new (``params``)' of '``name``'"; 
                    change = change; 
                    selection = DefaultRegion(loc, 0);
                };
            }
        }
    }

    Tree.Statement? findLastExecutable(Tree.ClassBody? body) {
        variable Tree.Statement? les = null;
        if (exists body) {
            for (st in body.statements) {
                if (isExecutableStatement(st) 
                    || st is Tree.Constructor) {
                    les = st;
                }
            }
        }
        return les;
    }

    Boolean isExecutableStatement(Tree.Statement s) {
        value unit = s.unit;
        switch (s)
        case (is Tree.ExecutableStatement) {
            if (is Tree.SpecifierStatement s) {
                // shortcut refinement statements with => 
                // aren't really "executable"
                return !(s.specifierExpression 
                            is Tree.LazySpecifierExpression 
                        && !s.refinement);
            }
            else {
                return true;
            }
        }
        case (is Tree.AttributeDeclaration) {
            value sie = s.specifierOrInitializerExpression;
            return !sie is Tree.LazySpecifierExpression 
                    && !s.declarationModel.formal;
        }
        case (is Tree.MethodDeclaration) {
            value sie = s.specifierExpression;
            return !sie is Tree.LazySpecifierExpression 
                    && !s.declarationModel.formal;
        }
        case (is Tree.ObjectDefinition) {
            if (s.extendedType exists) {
                if (exists et = s.extendedType.type.typeModel,
                    !et.declaration==unit.objectDeclaration 
                 && !et.declaration==unit.basicDeclaration) {
                    return true;
                }
            }
            
            if (exists ocb = s.classBody) {
                value statements = ocb.statements;
                variable value i = statements.size() - 1;
                while (i >= 0) {
                    value st = statements.get(i);
                    if (isExecutableStatement(st) 
                        || st is Tree.Constructor) {
                        return true;
                    }
                    i--;
                }
                return false;
            }
            
            return false;
        }
        else {
            return false;
        }
    }

}
