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
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared object convertThenElseToIfElse {
    
    shared void addConvertToIfElseProposal(QuickFixData data, 
        Tree.Statement? statement) {
             
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
        
        String test;
        String elseTerm;
        String thenTerm;
        
        switch (op = TreeUtil.unwrapExpressionUntilTerm(operation))
        case (is Tree.DefaultOp) {
            if (is Tree.ThenOp thenOp = op.leftTerm) {
                thenTerm = doc.getNodeText(thenOp.rightTerm);
                test = doc.getNodeText(thenOp.leftTerm);
            }
            else {
                value leftTerm = op.leftTerm;
                value leftTermStr = doc.getNodeText(leftTerm);
                if (is Tree.BaseMemberExpression leftTerm) {
                    thenTerm = leftTermStr;
                    test = "exists " + leftTermStr;
                }
                else {
                    value id = nodes.nameProposals {
                        node = leftTerm;
                        rootNode = data.rootNode;
                    }[0];
                    test = "exists " + id.string + " = " + leftTermStr;
                    thenTerm = id.string;
                }
            }
            
            elseTerm = doc.getNodeText(op.rightTerm);
        }
        case (is Tree.ThenOp) {
            thenTerm = doc.getNodeText(op.rightTerm);
            test = doc.getNodeText(op.leftTerm);
            elseTerm = "null";
        }
        case (is Tree.IfExpression) {
            thenTerm = doc.getNodeText(op.ifClause.expression);
            elseTerm = if (exists el = op.elseClause)
                       then doc.getNodeText(el.expression)
                       else "";
            value cl = op.ifClause.conditionList;
            test = doc.getNodeText(cl);
        }
        else {
            return;
        }
        
        value baseIndent = doc.getIndent(statement);
        value indent = platformServices.document.defaultIndent;
        value replace = StringBuilder();
        value delim = doc.defaultLineDelimiter;
        if (exists dec = declaration) {
            replace.append(dec)
                   .append(delim)
                   .append(baseIndent);
        }
        
        replace.append("if (")
                .append(removeEnclosingParenthesis(test))
                .append(") {")
                .append(delim)
                .append(baseIndent)
                .append(indent)
                .append(action)
                .append(removeEnclosingParenthesis(thenTerm))
                .append(";")
                .append(delim)
                .append(baseIndent)
                .append("}")
                .append(delim)
                .append(baseIndent)
                .append("else {")
                .append(delim)
                .append(baseIndent)
                .append(indent)
                .append(action)
                .append(removeEnclosingParenthesis(elseTerm))
                .append(";")
                .append(delim)
                .append(baseIndent)
                .append("}");
        value change 
                = platformServices.document.createTextChange {
            name = "Convert to If Else";
            input = data.phasedUnit;
        };
        change.addEdit(ReplaceEdit {
            start = statement.startIndex.intValue();
            length = statement.distance.intValue();
            text = replace.string;
        });
        
        data.addQuickFix {
            description = "Convert to 'if' 'else' statement";
            change = change;
            selection = DefaultRegion(statement.startIndex.intValue(), 0);
        };
    }
    
    String removeEnclosingParenthesis(String s) 
            => if (exists f = s.first, f == '(',
                   exists l = s.last, l == ')') 
            then s[1..s.size-2] else s;
}
