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
import java.util.regex {
    Pattern
}
import ceylon.interop.java {
    javaString
}
shared interface ConvertIfElseToThenElseQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared void addConvertToThenElseProposal(Data data, IFile file, IDocument doc,
        Tree.Statement? statement) {
        
        value result = createTextChange(data, doc, statement, file);
        if (exists [text, offset, change] = result) {
            value desc = text.replace("If", "'if'")
                .replace("Then", "'then'")
                .replace("Else", "'else'")
                + " Expression";
            newProposal(data, desc, change, DefaultRegion(offset, 0));
        }
    }
    
    [String, Integer, TextChange]? createTextChange(Data data, IDocument doc, 
        Tree.Statement? statement, IFile file) {
        
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
        
        variable value replaceFrom = statement.startIndex.intValue();
        variable value test = removeEnclosingParenthesis(getTerm(doc, conditionList));

        String thenStr;
        String  elseStr;
        String? attributeIdentifier;
        String operator;
        variable String action;
        
        if (is Tree.Return ifBlockNode) {
            value ifReturn = ifBlockNode;
            if (!is Tree.Return elseBlockNode) {
                return null;
            }
            
            attributeIdentifier = null;
            action = "return ";
            operator = "";
            thenStr = getOperands(doc, ifReturn.expression);
            elseStr = getOperands(doc, elseBlockNode.expression);
        } else if (is Tree.SpecifierStatement ifBlockNode) {
            value ifSpecifierStmt = ifBlockNode;
            value attrId = getTerm(doc, ifSpecifierStmt.baseMemberExpression);
            operator = " = ";
            action = attrId + operator;
            if (!is Tree.SpecifierStatement elseBlockNode) {
                return null;
            }
            
            value elseId = getTerm(doc, elseBlockNode.baseMemberExpression);

            if (!attrId.equals(elseId)) {
                return null;
            }
            
            attributeIdentifier = attrId;
            thenStr = getOperands(doc, ifSpecifierStmt.specifierExpression.expression.term);
            elseStr = getOperands(doc, (elseBlockNode).specifierExpression.expression.term);
        } else {
            return null;
        }
        
        if (exists attributeIdentifier) {
            value prevStatement = findPreviousStatement(data, doc, statement);
            if (exists prevStatement) {
                if (is Tree.AttributeDeclaration prevStatement) {
                    value attrDecl = prevStatement;
                    if (attributeIdentifier.equals(getTerm(doc, attrDecl.identifier))) {
                        action = removeSemiColon(getTerm(doc, attrDecl)) + operator;
                        replaceFrom = attrDecl.startIndex.intValue();
                    }
                }
            }
        }
        
        Boolean abbreviateToElse;
        Boolean abbreviateToThen;
        
        if (conditionList.conditions.size()==1) {
            value condition = conditionList.conditions[0];
            
            if (is Tree.ExistsCondition condition, 
                is Tree.Variable variable = condition.variable, 
                thenStr == getTerm(doc, variable.identifier)) {
                value existsExpr = variable.specifierExpression.expression;
                test = getTerm(doc, existsExpr);
                abbreviateToElse = true;
            }
            else {
                abbreviateToElse = false;
            }
            
            abbreviateToThen = 
                    condition is Tree.BooleanCondition && 
                    elseStr.equals("null");
            
        }
        else {
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
        
        
        value change = newTextChange(desc, file);
        addEditToChange(change, newReplaceEdit(replaceFrom, 
            statement.endIndex.intValue() - replaceFrom, replace.string));
        
        return [desc, replaceFrom, change];
    }
    
    String getOperands(IDocument doc, Tree.Term operand) {
        value term = getTerm(doc, operand);
        if (hasLowerPrecedenceThenElse(operand)) {
            return "(" + term + ")";
        }
        
        return term;
    }
    
    Boolean hasLowerPrecedenceThenElse(Tree.Term operand) {
        value node = if (is Tree.Expression exp = operand)
                     then exp.term
                     else operand;
        
        return node is Tree.DefaultOp|Tree.ThenOp|Tree.AssignOp;
    }
    
    String removeSemiColon(String term) {
        if (term.endsWith(";")) {
            return term[0..term.size - 2];
        }
        
        return term;
    }
    
    Tree.Statement? findPreviousStatement(Data data, IDocument doc, Tree.Statement statement) {
        value cu = data.rootNode;
        
        variable value previousLineNo = getLineOfOffset(doc, statement.startIndex.intValue());
        
        while (previousLineNo > 1) {
            previousLineNo--;
            value lineStart = getLineStartOffset(doc, previousLineNo);
            value prevLine = getLineContent(doc, previousLineNo);
            value m = Pattern.compile("(\\s*)\\w+").matcher(javaString(prevLine));
            if (m.find()) {
                value whitespaceLen = m.group(1).size;
                value node = nodes.findNode(cu, null, lineStart + whitespaceLen,
                    lineStart + whitespaceLen + 1);
                
                if (exists node) {
                    return nodes.findStatement(cu, node);
                }
            }
        }
        
        return null;
    }
    
    String removeEnclosingParenthesis(String s) {
        value first = s.first;
        value last = s.last;
        if (exists first, first == '(',
            exists last, last == ')') {
            
            return s[1..s.size - 2];
        }
        
        return s;
    }
    
    String getTerm(IDocument doc, Node node)
            => getDocContent(doc, node.startIndex.intValue(), node.distance.intValue());

}