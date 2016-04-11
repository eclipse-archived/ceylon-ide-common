import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
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
                        that.startIndex.intValue() 
                                <= data.node.startIndex.intValue(),
                        that.endIndex.intValue() 
                                >= data.node.endIndex.intValue()) {
                        
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
            value test = invertCondition(doc, ifCondition);
            
            value elseIndent = indents.getIndent(elseBlock, doc);
            value thenIndent = indents.getIndent(ifBlock, doc);
            value delim = indents.getDefaultLineDelimiter(doc);
            value elseStr = text(doc, elseBlock);
            
            value replace = StringBuilder();
            replace.append("if (").append(test).append(")");
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
            
            replace.append("else ").append(text(doc, ifBlock));
            value change = newTextChange("Invert If Then Else", file);
            addEditToChange(change, 
                newReplaceEdit {
                    start = ifExpr.startIndex.intValue();
                    length = ifExpr.distance.intValue();
                    text = replace.string;
                });
            
            newProposal {
                data = data;
                desc = "Invert 'if' 'then' 'else' expression";
                change = change;
                region = DefaultRegion(ifExpr.startIndex.intValue(), 0);
            };
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
        value test = invertCondition(doc, ifCondition);
        
        value baseIndent = indents.getIndent(ifStmt, doc);
        value indent = indents.defaultIndent;
        value delim = indents.getDefaultLineDelimiter(doc);
        value elseStr = addEnclosingBraces {
            s = text(doc, elseBlock);
            baseIndent = baseIndent;
            _indent = indent;
            delim = delim;
        };
        value replace = StringBuilder();
        replace.append("if (").append(test).append(") ").append(elseStr);
        
        if (isElseOnOwnLine(doc, ifBlock, elseBlock)) {
            replace.append(delim).append(baseIndent);
        } else {
            replace.append(" ");
        }
        
        replace.append("else ").append(text(doc, ifBlock));
        value change = newTextChange("Invert If Else", file);
        addEditToChange(change, 
            newReplaceEdit {
                start = ifStmt.startIndex.intValue();
                length = ifStmt.distance.intValue();
                text = replace.string;
            });
        
        newProposal(data, "Invert 'if' 'else' statement", change, 
            DefaultRegion(ifStmt.startIndex.intValue(), 0));
    }
    
    Boolean isElseOnOwnLine(IDocument doc, Node ifBlock, Node elseBlock) 
            => getLineOfOffset(doc, ifBlock.stopIndex.intValue())
                != getLineOfOffset(doc, elseBlock.startIndex.intValue());
    
    String addEnclosingBraces(String s, String baseIndent, String _indent, String delim) {
        assert(exists first = s.first);
        if (first != '{') {
            return "{" + delim + baseIndent + _indent 
                    + indent(s, _indent, delim) + delim + baseIndent + "}";
        }
        else {
            return s;
        }
    }
    
    String indent(String s, String indentation, String delim) 
            => javaString(s)
                .replaceAll(delim + "(\\s*)", delim + "$1" + indentation);
    
    String text(IDocument doc, Node node) 
            => getDocContent {
                doc = doc;
                start = node.startIndex.intValue();
                length = node.distance.intValue();
            };
   
   String invertTerm(IDocument doc, Tree.Term? term) {
       switch (term)
       case (null) {
           return ""; 
       }
       case (is Tree.BaseMemberExpression) {
           value unit = term.unit;
           value td = unit.trueValueDeclaration;
           value fd = unit.falseValueDeclaration;
           if (term.declaration==td) {
               return fd.getName(unit);
           }
           else if (term.declaration==fd) {
               return td.getName(unit);
           }
           else {
               return "!" + text(doc, term);
           }
       }
       case (is Tree.NotOp) {
           return text(doc, term.term);
       }
       case (is Tree.EqualOp) {
           return text(doc, term.leftTerm) + "!=" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.NotEqualOp) {
           return text(doc, term.leftTerm) + "=" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.SmallerOp) {
           return text(doc, term.leftTerm) + ">=" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.SmallAsOp) {
           return text(doc, term.leftTerm) + ">" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.LargerOp) {
           return text(doc, term.leftTerm) + "<=" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.LargeAsOp) {
           return text(doc, term.leftTerm) + "<" + 
                   text(doc, term.rightTerm);
       }
       case (is Tree.AndOp) {
           //TODO: preserve whitespace!
           return invertTerm(doc, term.leftTerm) + " || " + 
                   invertTerm(doc, term.rightTerm);
       }
       case (is Tree.OrOp) {
           value left 
                   = term.leftTerm is Tree.AndOp 
                    then "(" + invertTerm(doc, term.leftTerm) + ")"
                    else invertTerm(doc, term.leftTerm);
           value right 
                   = term.rightTerm is Tree.AndOp 
                    then "(" + invertTerm(doc, term.rightTerm) + ")"
                    else invertTerm(doc, term.rightTerm);
           //TODO: preserve whitespace!
           return left + " && " + right;
       }
       case (is Tree.Expression) {
           if (term.token exists) {
               return "!" + text(doc, term);
           }
           else {
               return invertTerm(doc, term.term);
           }
       }
       case (is Tree.ThenOp
               |Tree.DefaultOp
               |Tree.LetExpression
               |Tree.SwitchExpression
               |Tree.IfExpression
               |Tree.AssignmentOp) {
           //something with a lower precedence than ! operator
           return "!(" + text(doc, term) + ")";
       }
       else {
           return "!" + text(doc, term);
       }
   }
   
   String invertCondition(IDocument doc, Tree.Condition? ifCondition) {
       switch(ifCondition)
       case (is Tree.BooleanCondition) {
           Tree.Term? term = ifCondition.expression.term;
           if (is Tree.NotOp term, is Tree.Expression e = term.term) {
               //special case for eliminating toplevel parens
               return text(doc, e.term);
           }
           else {
               return invertTerm(doc, term);
           }
       }
       case (is Tree.ExistsCondition|Tree.NonemptyCondition|Tree.IsCondition) {
           return "!" + text(doc, ifCondition);
       }
       else {
           return "";
       }
   }
   

}