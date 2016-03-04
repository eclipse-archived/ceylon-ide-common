import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import ceylon.interop.java {
    javaString
}

shared interface InvertIfElseQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared void addInvertIfElseProposal(Data data, IFile file, IDocument doc, Tree.Statement? statement) {
        addInvertIfElseExpressionProposal(data, file, doc);
        addInvertIfElseStatementProposal(data, file, doc, statement);
    }
    
    void addInvertIfElseExpressionProposal(Data data, IFile file, IDocument doc) {
        try {
            variable Tree.IfExpression? result = null;
            
            object extends Visitor() {
                shared actual void visit(Tree.IfExpression that) {
                    super.visit(that);
                    if (that.ifClause exists,
                        that.elseClause exists,
                        that.startIndex.intValue() <= data.node.startIndex.intValue(),
                        that.endIndex.intValue() >= data.node.endIndex.intValue()) {
                        
                        result = that;
                    }
                }
            }.visit(data.rootNode);

            value ifExpr = result;
            
            if (!exists ifExpr) {
                return;
            }
            
            value ifClause = ifExpr.ifClause;
            value ifBlock = ifClause.expression;
            value elseBlock = ifExpr.elseClause.expression;
            value conditions = ifClause.conditionList.conditions;
            if (conditions.size() != 1) {
                return;
            }
            
            value ifCondition = conditions.get(0);
            variable String? test = null;
            variable value term = getTerm(doc, ifCondition);
            
            if (term.equals("(true)")) {
                test = "false";
            } else if (term.equals("(false)")) {
                test = "true";
            } else if (is Tree.BooleanCondition ifCondition) {
                value boolCond = ifCondition;
                value bt = boolCond.expression.term;
                if (is Tree.NotOp bt) {
                    value no = bt;
                    value t = getTerm(doc, no.term);
                    test = removeEnclosingParenthesis(t);
                } else if (is Tree.EqualityOp bt) {
                    value eo = bt;
                    test = getInvertedEqualityTest(doc, eo);
                } else if (is Tree.ComparisonOp bt) {
                    value co = bt;
                    test = getInvertedComparisonTest(doc, co);
                } else if (!(bt is Tree.OperatorExpression) || bt is Tree.UnaryOperatorExpression) {
                    term = removeEnclosingParenthesis(term);
                }
            } else {
                term = removeEnclosingParenthesis(term);
            }
            
            if (!exists _ = test) {
                if (term.startsWith("!")) {
                    test = term.spanFrom(1);
                } else {
                    test = "!" + term;
                }
            }
            
            value elseIndent = indents.getIndent(elseBlock, doc);
            value thenIndent = indents.getIndent(ifBlock, doc);
            value delim = indents.getDefaultLineDelimiter(doc);
            value elseStr = getTerm(doc, elseBlock);
            
            test = removeEnclosingParenthesis(test else "");
            value replace = StringBuilder();
            replace.append("if (").append(test else "").append(")");
            if (isElseOnOwnLine(doc, ifCondition, ifBlock)) {
                replace.append(delim).append(thenIndent);
            } else {
                replace.append(" ");
            }
            
            replace.append("then ").append(elseStr);
            if (isElseOnOwnLine(doc, ifBlock, elseBlock)) {
                replace.append(delim).append(elseIndent);
            } else {
                replace.append(" ");
            }
            
            replace.append("else ").append(getTerm(doc, ifBlock));
            value change = newTextChange("Invert If Then Else", file);
            addEditToChange(change, newReplaceEdit(ifExpr.startIndex.intValue(),
                ifExpr.distance.intValue(), replace.string));
            
            newProposal(data, "Invert 'if' 'then' 'else' expression", change, 
                DefaultRegion(ifExpr.startIndex.intValue(), 0));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    void addInvertIfElseStatementProposal(Data data, IFile file, IDocument doc,
        Tree.Statement? statement) {
        
        if (!exists statement) {
            return;
        }
        Tree.IfStatement ifStmt;

        if (is Tree.IfStatement statement) {
            if (!exists eb = statement.elseClause) {
                return;
            }
            ifStmt = statement;
        } else {
            variable Tree.IfStatement? result = null;

            object extends Visitor() {
                shared actual void visit(Tree.IfStatement that) {
                    super.visit(that);
                    if (that.ifClause exists,
                        that.elseClause exists,
                        that.startIndex.intValue() <= statement.startIndex.intValue(),
                        that.endIndex.intValue() >= statement.endIndex.intValue()) {
                        
                        result = that;
                    }
                }
            }.visit(data.rootNode);
            
            if (exists r = result) {
                ifStmt = r;
            } else {
                return;
            }
        }
        
        value ifClause = ifStmt.ifClause;
        value ifBlock = ifClause.block;
        value elseBlock = ifStmt.elseClause.block;
        value conditions = ifClause.conditionList.conditions;
        if (conditions.size() != 1) {
            return;
        }
        
        value ifCondition = conditions.get(0);
        variable String? test = null;
        variable value term = getTerm(doc, ifCondition);
        
        if (term.equals("(true)")) {
            test = "false";
        } else if (term.equals("(false)")) {
            test = "true";
        } else if (is Tree.BooleanCondition ifCondition) {
            value boolCond = ifCondition;
            value bt = boolCond.expression.term;
            if (is Tree.NotOp bt) {
                value no = bt;
                value t = getTerm(doc, no.term);
                test = removeEnclosingParenthesis(t);
            } else if (is Tree.EqualityOp bt) {
                value eo = bt;
                test = getInvertedEqualityTest(doc, eo);
            } else if (is Tree.ComparisonOp bt) {
                value co = bt;
                test = getInvertedComparisonTest(doc, co);
            } else if (!(bt is Tree.OperatorExpression) || bt is Tree.UnaryOperatorExpression) {
                term = removeEnclosingParenthesis(term);
            }
        } else {
            term = removeEnclosingParenthesis(term);
        }
        
        if (!exists _ = test) {
            if (term.startsWith("!")) {
                test = term.spanFrom(1);
            } else {
                test = "!" + term;
            }
        }
        
        value baseIndent = indents.getIndent(ifStmt, doc);
        value indent = indents.defaultIndent;
        value delim = indents.getDefaultLineDelimiter(doc);
        value elseStr = addEnclosingBraces(getTerm(doc, elseBlock), baseIndent, indent, delim);
        test = removeEnclosingParenthesis(test else "");
        value replace = StringBuilder();
        replace.append("if (").append(test else "").append(") ").append(elseStr);
        
        if (isElseOnOwnLine(doc, ifBlock, elseBlock)) {
            replace.append(delim).append(baseIndent);
        } else {
            replace.append(" ");
        }
        
        replace.append("else ").append(getTerm(doc, ifBlock));
        value change = newTextChange("Invert If Else", file);
        addEditToChange(change, newReplaceEdit(ifStmt.startIndex.intValue(),
            ifStmt.distance.intValue(), replace.string));
        
        newProposal(data, "Invert 'if' 'else' statement", change, 
            DefaultRegion(ifStmt.startIndex.intValue(), 0));
    }
    
    String getInvertedEqualityTest(IDocument doc, Tree.EqualityOp equalityOp) {
        value op = if (equalityOp is Tree.EqualOp) then " != " else " == ";
        return getTerm(doc, equalityOp.leftTerm) + op + getTerm(doc, equalityOp.rightTerm);
    }
    
    String getInvertedComparisonTest(IDocument doc, Tree.ComparisonOp compOp) {
        String op;
        
        if (is Tree.LargerOp compOp) {
            op = " <= ";
        } else if (is Tree.LargeAsOp compOp) {
            op = " < ";
        } else if (is Tree.SmallerOp compOp) {
            op = " >= ";
        } else if (is Tree.SmallAsOp compOp) {
            op = " > ";
        } else {
            throw Exception("Unknown Comparision op " + compOp.string);
        }
        
        return getTerm(doc, compOp.leftTerm) + op + getTerm(doc, compOp.rightTerm);
    }
    
    Boolean isElseOnOwnLine(IDocument doc, Node ifBlock, Node elseBlock) {
        return getLineOfOffset(doc, ifBlock.stopIndex.intValue())
                != getLineOfOffset(doc, elseBlock.startIndex.intValue());
    }
    
    String addEnclosingBraces(String s, String baseIndent, String _indent, String delim) {
        assert(exists first = s.first);
        if (first != '{') {
            return "{" + delim + baseIndent + _indent 
                    + indent(s, _indent, delim) + delim + baseIndent + "}";
        }
        
        return s;
    }
    
    String indent(String s, String indentation, String delim) {
        return javaString(s)
                .replaceAll(delim + "(\\s*)", delim + "$1" + indentation);
    }
    
    String removeEnclosingParenthesis(String s) {
        assert(exists first = s.first);
        if (first == '(') {
            variable value endIndex = 0;
            variable value startIndex = 0;
            while ((endIndex = (s.firstOccurrence(')', endIndex + 1) else -1)) > 0) {
                if (endIndex == s.size - 1) {
                    return s.span(1, s.size - 2);
                }
                
                if ((startIndex = (s.firstOccurrence('(', startIndex + 1) else -1)) > endIndex) {
                    return s;
                }
            }
        }
        
        return s;
    }
    
    String getTerm(IDocument doc, Node node) {
        return getDocContent(doc, node.startIndex.intValue(), node.distance.intValue());
    }
}