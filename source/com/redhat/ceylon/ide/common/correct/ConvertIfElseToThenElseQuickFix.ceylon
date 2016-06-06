import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    ReplaceEdit,
    TextChange
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

import java.util.regex {
    Pattern
}

shared object convertIfElseToThenElseQuickFix {
    
    shared void addConvertToThenElseProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (exists [text, offset, change] 
                = createTextChange(data, statement)) {
            value desc 
                    = text.replace("If", "'if'")
                          .replace("Then", "'then'")
                          .replace("Else", "'else'")
                    + " expression";
            data.addQuickFix {
                description = desc;
                change = change;
                selection = DefaultRegion(offset);
            };
        }
    }
    
    [String, Integer, TextChange]? createTextChange(QuickFixData data, 
        Tree.Statement? statement) {
        
        value doc = data.document;
        
        if (!is Tree.IfStatement statement) {
            return null;
        }
        
        value ifStmt = statement;
        if (!ifStmt.elseClause exists) {
            return null;
        }
        
        value ifBlock = ifStmt.ifClause.block;
        if (ifBlock.statements.size() != 1) {
            return null;
        }
        
        value elseBlock = ifStmt.elseClause.block;
        if (elseBlock.statements.size() != 1) {
            return null;
        }
        
        value ifBlockNode = ifBlock.statements.get(0);
        value elseBlockNode = elseBlock.statements.get(0);
        value conditionList = ifStmt.ifClause.conditionList;
        
        Integer replaceFrom;

        String thenStr;
        String elseStr;
        String? attributeIdentifier;
        String operator;
        String action;
        
        switch (ifBlockNode)
        case (is Tree.Return) {
            value ifReturn = ifBlockNode;
            if (!is Tree.Return elseBlockNode) {
                return null;
            }
            
            attributeIdentifier = null;
            action = "return ";
            operator = "";
            thenStr = getOperands(doc, ifReturn.expression);
            elseStr = getOperands(doc, elseBlockNode.expression);
            replaceFrom = statement.startIndex.intValue();
        }
        case (is Tree.SpecifierStatement) {
            value ifSpecifierStmt = ifBlockNode;
            value attrId 
                    = doc.getNodeText(
                        ifSpecifierStmt.baseMemberExpression);
            operator = " = ";
            
            if (!is Tree.SpecifierStatement elseBlockNode) {
                return null;
            }
            
            value elseId 
                    = doc.getNodeText(
                        elseBlockNode.baseMemberExpression);

            if (attrId!=elseId) {
                return null;
            }
            
            attributeIdentifier = attrId;
            thenStr = getOperands(doc, 
                ifSpecifierStmt.specifierExpression.expression.term);
            elseStr = getOperands(doc, 
                elseBlockNode.specifierExpression.expression.term);

            if (is Tree.AttributeDeclaration prevStatement 
                        = findPreviousStatement(data, statement),
                attrId == doc.getNodeText(prevStatement.identifier)) {
                action = removeSemiColon(doc.getNodeText(prevStatement)) 
                        + operator;
                replaceFrom = prevStatement.startIndex.intValue();
            }
            else {
                action = attrId + operator;
                replaceFrom = statement.startIndex.intValue();
            }
            
        }
        else {
            return null;
        }
        
        Boolean abbreviateToElse;
        Boolean abbreviateToThen;
        
        String test;
        value conditionText 
                = removeEnclosingParenthesis(
                    doc.getNodeText(conditionList));
        if (conditionList.conditions.size()==1) {
            
            if (is Tree.ExistsCondition condition 
                    = conditionList.conditions[0], 
                is Tree.Variable variable = condition.variable, 
                thenStr == doc.getNodeText(variable.identifier)) {
                value existsExpr = variable.specifierExpression.expression;
                test = doc.getNodeText(existsExpr);
                abbreviateToElse = true;
            }
            else {
                test = conditionText;
                abbreviateToElse = false;
            }
            
            abbreviateToThen = 
                    conditionList.conditions[0] 
                        is Tree.BooleanCondition && 
                    elseStr.equals("null");
            
        }
        else {
            test = conditionText;
            abbreviateToElse = false;
            abbreviateToThen = false;
        }
        
        value replace = StringBuilder();
        replace.append(action);
        if (!abbreviateToThen, !abbreviateToElse) {
            replace.append("if (");
        }
        
        replace.append(test);
        if (!abbreviateToThen, !abbreviateToElse) {
            replace.append(")");
        }
        
        if (!abbreviateToElse) {
            replace.append(" then ").append(thenStr);
        }
        
        if (!abbreviateToThen) {
            replace.append(" else ").append(elseStr);
        }
        
        replace.append(";");
        
        String desc = if (abbreviateToThen)
                      then "Convert to Then"
                      else if (abbreviateToElse) 
                      then "Convert to Else"
                      else "Convert to If Then Else";
        
        
        value change 
                = platformServices.document.createTextChange {
            name = desc;
            input = data.phasedUnit;
        };
        change.addEdit(ReplaceEdit {
            start = replaceFrom;
            length = statement.endIndex.intValue() 
                    - replaceFrom;
            text = replace.string;
        });
        
        return [desc, replaceFrom, change];
    }
    
    String getOperands(CommonDocument doc, Tree.Term operand) {
        value term = doc.getNodeText(operand);
        return if (hasLowerPrecedenceThenElse(operand)) 
            then "(``term``)" else term;
    }
    
    String removeSemiColon(String term) 
            => if (term.endsWith(";")) 
            then term[0..term.size - 2] 
            else term;
    
    String removeEnclosingParenthesis(String s) 
            => if (exists first = s.first, first == '(',
                   exists last = s.last, last == ')') 
            then s[1..s.size-2] 
            else s;

}

Boolean hasLowerPrecedenceThenElse(Tree.Term operand) {
    value node = if (is Tree.Expression exp = operand)
    then exp.term
    else operand;
    return node is Tree.DefaultOp|Tree.ThenOp|Tree.AssignOp;
}

Tree.Statement? findPreviousStatement(QuickFixData data, 
    Tree.Statement statement) {
    value rootNode = data.rootNode;
    value doc = data.document;
    
    variable value previousLineNo 
            = doc.getLineOfOffset(statement.startIndex.intValue());
    
    while (previousLineNo > 1) {
        previousLineNo--;
        value lineStart 
                = doc.getLineStartOffset(previousLineNo);
        value prevLine 
                = doc.getLineContent(previousLineNo);
        value m = Pattern.compile("(\\s*)\\w+")
                .matcher(javaString(prevLine));
        if (m.find()) {
            value whitespaceLen = m.group(1).size;
            if (exists node = nodes.findNode {
                node = rootNode;
                tokens = null;
                startOffset = lineStart + whitespaceLen;
                endOffset = lineStart + whitespaceLen + 1;
            }) {
                return nodes.findStatement(rootNode, node);
            }
        }
    }
    
    return null;
}

