import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Function
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
                    = platformServices.document.createTextChange {
                name = "Add Default Constructor";
                input = data.phasedUnit;
            };
            
            if (exists body = cd.classBody, 
                !cd.parameterList exists,
                cd.identifier exists) {
                value doc = data.document;
                value uninitialized 
                        = correctionUtil.collectUninitializedMembers(body);
                value les = findLastExecutable(body);
                value defaultIndent = platformServices.document.defaultIndent;
                value delim = doc.defaultLineDelimiter;
                value indent 
                        = if (!exists les)
                        then doc.getIndent(cd) 
                                + defaultIndent
                        else doc.getIndent(les);
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
                                + doc.getIndent(cd);
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
                if (exists name = cd.declarationModel?.name) {
                    data.addQuickFix {
                        description = "Add constructor 'new (``params``)' of '``name``'"; 
                        change = change; 
                        selection = DefaultRegion(loc, 0);
                        kind = QuickFixKind.addConstructor;
                    };
                }
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
        assert(exists unit = s.unit);
        switch (s)
        case (is Tree.ExecutableStatement) {
            if (is Tree.SpecifierStatement s) {
                // shortcut refinement statements with => 
                // aren't really "executable"
                
                Tree.SpecifierExpression? se = s.specifierExpression;
                return !(se is Tree.LazySpecifierExpression 
                        && !s.refinement);
            }
            else {
                return true;
            }
        }
        case (is Tree.AttributeDeclaration) {
            Tree.SpecifierOrInitializerExpression? sie = s.specifierOrInitializerExpression;
            return !sie is Tree.LazySpecifierExpression 
                    && !s.declarationModel.formal;
        }
        case (is Tree.MethodDeclaration) {
            Tree.SpecifierExpression? sie = s.specifierExpression;
            Function? declarationModel = s.declarationModel;
            if (exists declarationModel) {
                return !sie is Tree.LazySpecifierExpression 
                        && !declarationModel.formal;
            }
            return false;
        }
        case (is Tree.ObjectDefinition) {
            if (s.extendedType exists) {
                if (exists et = s.extendedType.type?.typeModel,
                    exists declaration = et.declaration,
                    !declaration==unit.objectDeclaration 
                 && !declaration==unit.basicDeclaration) {
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
