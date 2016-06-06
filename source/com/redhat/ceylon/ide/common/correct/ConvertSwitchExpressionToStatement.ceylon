import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    CustomTree,
    TreeUtil
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object convertSwitchExpressionToStatement {
    
    shared void addConvertSwitchExpressionToStatementProposal(
        QuickFixData data, Tree.Statement? statement) {
             
        value doc = data.document;
        String action;
        String? declaration;
        Tree.Term operation;
        switch (statement)
        case (is Tree.Return) {
            action = "return ";
            declaration = null;
            if (exists e = statement.expression,
                exists t = e.term) {
                operation = t;
            }
            else {
                return;
            }            
        }
        case (is Tree.ExpressionStatement) {
            declaration = null;
            if (exists e = statement.expression,
                is Tree.AssignOp t = e.term) {
                action = doc.getNodeText(t.leftTerm) + " = ";
                operation = t.rightTerm;
            }
            else {
                return;
            }
        }
        case (is Tree.SpecifierStatement) {
            if (statement.refinement) {
                return;
            }
            declaration = null;
            action = doc.getNodeText(statement.baseMemberExpression) + " = ";
            operation = statement.specifierExpression.expression;
        }
        case (is CustomTree.AttributeDeclaration) {
            if (!statement.identifier exists) {
                return;
            }
            
            value identifier = doc.getNodeText(statement.identifier);
            variable value annotations = "";
            if (!statement.annotationList.annotations.empty) {
                annotations = doc.getNodeText(statement.annotationList) + " ";
            }
            
            String type;
            if (is Tree.ValueModifier valueModifier = statement.type) {
                if (exists typeModel = valueModifier.typeModel) {
                    type = typeModel.asString();
                }
                else {
                    return;
                }
            }
            else {
                type = doc.getNodeText(statement.type);
            }
            
            declaration 
                    = annotations + type + " " + identifier + ";";
            if (exists sie = 
                    statement.specifierOrInitializerExpression,
                exists ex = sie.expression) {
                action = identifier + " = ";
                operation = sie.expression.term;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        assert (exists statement);
        
        if (is Tree.SwitchExpression op 
                = TreeUtil.unwrapExpressionUntilTerm(operation)) {

            value baseIndent = doc.getIndent(statement);
            value indent = platformServices.document.defaultIndent;
            
            value replace = StringBuilder();
            value delim = doc.defaultLineDelimiter;
            if (exists dec = declaration) {
                replace.append(dec)
                        .append(delim)
                        .append(baseIndent);
            }
            
            String test = doc.getNodeText(op.switchClause);
            replace.append(test).append(delim);
            for (caseClause in op.switchCaseList.caseClauses) {
                String it = doc.getNodeText(caseClause.caseItem);
                String term = doc.getNodeText(caseClause.expression);
                replace.append(baseIndent)
                        .append("case (")
                        .append(it)
                        .append(" {")
                        .append(delim)
                        .append(baseIndent)
                        .append(indent)
                        .append(action)
                        .append(removeEnclosingParenthesis(term))
                        .append(";")
                        .append(delim)
                        .append(baseIndent)
                        .append("}")
                        .append(delim);
            }
            
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Switch Statement";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                start = statement.startIndex.intValue();
                length = statement.distance.intValue();
                text = replace.string;
            });
            
            data.addQuickFix {
                description = "Convert to 'switch' statement";
                change = change;
                selection = DefaultRegion(statement.startIndex.intValue(), 0);
            };
        }
    }
    
    String removeEnclosingParenthesis(String s) 
            => if (exists f = s.first, f == '(',
                   exists l = s.last, l == ')') 
            then s[1..s.size-2] else s;
}
