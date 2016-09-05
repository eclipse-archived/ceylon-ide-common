import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil,
    Node
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

shared object convertThenElseToIfElseQuickFix {
    
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
                is Tree.AssignOp t = e.term,
                exists leftTerm = t.leftTerm,
                exists rightTerm = t.rightTerm) {
                action = doc.getNodeText(leftTerm) + " = ";
                operation = rightTerm;
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
        case (is Tree.AttributeDeclaration) {
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
                exists term = sie.expression?.term) {
                action = identifier + " = ";
                operation = term;
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

        function getNodeText(Node? node)
                => if (exists node)
        then doc.getNodeText(node) else "";
        
        switch (op = TreeUtil.unwrapExpressionUntilTerm(operation))
        case (is Tree.DefaultOp) {
            if (is Tree.ThenOp thenOp = op.leftTerm) {
                thenTerm = getNodeText(thenOp.rightTerm);
                test = getNodeText(thenOp.leftTerm);
            }
            else {
                value leftTerm = op.leftTerm;
                value leftTermStr = getNodeText(leftTerm);
                if (is Tree.BaseMemberExpression leftTerm) {
                    thenTerm = leftTermStr;
                    test = "exists " + leftTermStr;
                }
                else {
                    value id = nodes.nameProposals {
                        node = leftTerm;
                        rootNode = data.rootNode;
                    }[0];
                    test = "exists ``id`` = " + leftTermStr;
                    thenTerm = id.string;
                }
            }

            elseTerm = getNodeText(op.rightTerm);
        }
        case (is Tree.ThenOp) {
            thenTerm = getNodeText(op.rightTerm);
            test = getNodeText(op.leftTerm);
            elseTerm = "null";
        }
        case (is Tree.IfExpression) {
            thenTerm = getNodeText(op.ifClause.expression);
            elseTerm = getNodeText(op.elseClause ?. expression);
            value cl = op.ifClause.conditionList;
            test = getNodeText(cl);
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
            selection = DefaultRegion(statement.startIndex.intValue());
        };
    }
    
    String removeEnclosingParenthesis(String s) 
            => if (exists f = s.first, f == '(',
                   exists l = s.last, l == ')') 
            then s[1..s.size-2] else s;
}
