import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    CustomTree
}
import com.redhat.ceylon.model.typechecker.model {
    Type
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared interface ConvertThenElseToIfElse<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared void addConvertToIfElseProposal(Data data, IFile file, IDocument doc, 
        Tree.Statement? statement) {
     
        String action;
        variable String? declaration = null;
        variable Node operation;
        
        if (!exists statement) {
            return;
        }

        if (is Tree.Return statement) {
            value returnOp = statement;
            action = "return ";
            if (!returnOp.expression exists || !returnOp.expression.term exists) {
                return;
            }
            
            operation = returnOp.expression.term;
        } else if (is Tree.ExpressionStatement statement) {
            value expressionStmt = statement;
            if (!expressionStmt.expression exists) {
                return;
            }
            
            value expression = expressionStmt.expression;
            if (!expression.term exists) {
                return;
            }
            
            if (!(expression.term is Tree.AssignOp)) {
                return;
            }
            
            assert(is Tree.AssignOp assignOp = expression.term);
            action = getTerm(doc, assignOp.leftTerm) + " = ";
            operation = assignOp.rightTerm;
        } else if (is Tree.SpecifierStatement statement) {
            if (statement.refinement) {
                return;
            }
            action = getTerm(doc, statement.baseMemberExpression) + " = ";
            operation = statement.specifierExpression.expression;
        } else if (is CustomTree.AttributeDeclaration statement) {
            if (!statement.identifier exists) {
                return;
            }
            
            value identifier = getTerm(doc, statement.identifier);
            variable value annotations = "";
            if (!statement.annotationList.annotations.empty) {
                annotations = getTerm(doc, statement.annotationList) + " ";
            }
            
            String type;
            if (is Tree.ValueModifier valueModifier = statement.type) {
                Type? typeModel = valueModifier.typeModel;
                if (!exists typeModel) {
                    return;
                }
                
                type = typeModel.asString();
            } else {
                type = getTerm(doc, statement.type);
            }
            
            declaration = annotations + type + " " + identifier + ";";
            Tree.SpecifierOrInitializerExpression? sie = 
                    statement.specifierOrInitializerExpression;
            
            if (!exists sie) {
                return;
            }
            Tree.Expression? ex = sie.expression;
            if (!exists ex) {
                return;
            }
            
            action = identifier + " = ";
            operation = sie.expression.term;
        } else {
            return;
        }
        
        variable String test;
        variable String elseTerm;
        variable String thenTerm;
        while (is Tree.Expression o = operation) {
            operation = o.term;
        }
        
        if (is Tree.DefaultOp defaultOp = operation) {
            if (is Tree.ThenOp thenOp = defaultOp.leftTerm) {
                thenTerm = getTerm(doc, thenOp.rightTerm);
                test = getTerm(doc, thenOp.leftTerm);
            } else {
                value leftTerm = defaultOp.leftTerm;
                value leftTermStr = getTerm(doc, leftTerm);
                if (is Tree.BaseMemberExpression leftTerm) {
                    thenTerm = leftTermStr;
                    test = "exists " + leftTermStr;
                } else {
                    value id = nodes.nameProposals(leftTerm, false, data.rootNode).get(0);
                    test = "exists " + id.string + " = " + leftTermStr;
                    thenTerm = id.string;
                }
            }
            
            elseTerm = getTerm(doc, defaultOp.rightTerm);
        } else if (is Tree.ThenOp thenOp = operation) {
            thenTerm = getTerm(doc, thenOp.rightTerm);
            test = getTerm(doc, thenOp.leftTerm);
            elseTerm = "null";
        } else if (is Tree.IfExpression ie = operation) {
            thenTerm = getTerm(doc, ie.ifClause.expression);
            elseTerm = if (exists el = ie.elseClause)
                       then getTerm(doc, el.expression)
                       else "";
            value cl = ie.ifClause.conditionList;
            test = getTerm(doc, cl);
        } else {
            return;
        }
        
        value baseIndent = indents.getIndent(statement, doc);
        value indent = indents.defaultIndent;
        test = removeEnclosingParentesis(test);
        value replace = StringBuilder();
        value delim = indents.getDefaultLineDelimiter(doc);
        if (exists dec = declaration) {
            replace.append(dec).append(delim).append(baseIndent);
        }
        
        replace.append("if (").append(test).append(") {").append(delim).append(baseIndent).append(indent).append(action).append(thenTerm).append(";").append(delim).append(baseIndent).append("}").append(delim).append(baseIndent).append("else {").append(delim).append(baseIndent).append(indent).append(action).append(elseTerm).append(";").append(delim).append(baseIndent).append("}");
        value change = newTextChange("Convert to If Else", file);
        addEditToChange(change, newReplaceEdit(
            statement.startIndex.intValue(), statement.distance.intValue(),
            replace.string));
        
        newProposal(data, "Convert to 'if' 'else' statement", change,
            DefaultRegion(statement.startIndex.intValue(), 0));
    }
    
    String removeEnclosingParentesis(String s) {
        if (exists f = s.first, f == '(',
            exists l = s.last, l == ')') {
            return s.span(1, s.size - 2);
        }
        
        return s;
    }
    
    String getTerm(IDocument doc, Node node) {
        return getDocContent(doc, node.startIndex.intValue(), node.distance.intValue());
    }
}
