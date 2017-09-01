import java.lang {
    Types {
        nativeString
    }
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object invertIfElseQuickFix {
    
    shared void addInvertIfElseProposal(QuickFixData data, 
            Tree.Statement? statement) {
        addInvertIfElseExpressionProposal(data);
        addInvertIfElseStatementProposal(data, statement);
    }
    
    void addInvertIfElseExpressionProposal(QuickFixData data) {
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
            
            value ifClause = ifExpr.ifClause else null;
            if (!exists ifClause) {
                return;
            }

            value ifBlock = ifClause.expression else null;
            if (!exists ifBlock) {
                return;
            }
            value elseBlock = ifExpr.elseClause?.expression else null;
            if (!exists elseBlock) {
                return;
            }
            value conditions = ifClause.conditionList.conditions;
            if (conditions.size() != 1) {
                return;
            }
            
            value ifCondition = conditions.get(0);
            value doc = data.document;
            value test = invertCondition(doc, ifCondition);
            
            value elseIndent = doc.getIndent(elseBlock);
            value thenIndent = doc.getIndent(ifBlock);
            value delim = doc.defaultLineDelimiter;
            value elseStr = doc.getNodeText(elseBlock);
            
            value replace = StringBuilder();
            replace.append("if (")
                   .append(test)
                   .append(")");
            if (isElseOnOwnLine(doc, ifCondition, ifBlock)) {
                replace.append(delim)
                       .append(thenIndent);
            } else {
                replace.append(" ");
            }
            
            replace.append("then ")
                   .append(elseStr);
            if (isElseOnOwnLine(doc, ifBlock, elseBlock)) {
                replace.append(delim)
                       .append(elseIndent);
            } else {
                replace.append(" ");
            }
            
            replace.append("else ")
                   .append(doc.getNodeText(ifBlock));
            value change 
                    = platformServices.document.createTextChange {
                name = "Invert If Then Else";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                    start = ifExpr.startIndex.intValue();
                    length = ifExpr.distance.intValue();
                    text = replace.string;
                });
            
            data.addQuickFix {
                description = "Invert 'if' 'then' 'else' expression";
                change = change;
                selection = DefaultRegion(ifExpr.startIndex.intValue());
            };
        } catch (e) {
            e.printStackTrace();
        }
    }
    
    void addInvertIfElseStatementProposal(QuickFixData data, 
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
                        that.startIndex.intValue() 
                                <= statement.startIndex.intValue(),
                        that.endIndex.intValue() 
                                >= statement.endIndex.intValue()) {
                        
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
        
        Tree.IfClause ifClause = ifStmt.ifClause;
        Tree.ElseClause? elseClause = ifStmt.elseClause;
        if (!exists elseClause) {
            return;
        }
        Tree.Block? ifBlock = ifClause.block;
        Tree.Block? elseBlock = elseClause.block;
        if (!exists ifBlock) {
            return;
        }
        if (!exists elseBlock) {
            return;
        }
        Tree.ConditionList? conditionList = ifClause.conditionList;
        if (!exists conditionList) {
            return;
        }
        value conditions = conditionList.conditions;
        if (conditions.size() != 1) {
            return;
        }
        
        value ifCondition = conditions.get(0);
        value doc = data.document;
        value test = invertCondition(doc, ifCondition);
        
        value baseIndent = doc.getIndent(ifStmt);
        value indent = platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        value elseStr = addEnclosingBraces {
            s = doc.getNodeText(elseBlock);
            baseIndent = baseIndent;
            _indent = indent;
            delim = delim;
        };
        value replace = StringBuilder();
        replace.append("if (")
               .append(test)
               .append(") ")
               .append(elseStr);
        
        if (isElseOnOwnLine(doc, ifBlock, elseBlock)) {
            replace.append(delim)
                   .append(baseIndent);
        } else {
            replace.append(" ");
        }
        
        replace.append("else ")
               .append(doc.getNodeText(ifBlock));
        value change = platformServices.document.createTextChange {
            name = "Invert If Else";
            input = data.phasedUnit;
        };
        change.addEdit(ReplaceEdit {
                start = ifStmt.startIndex.intValue();
                length = ifStmt.distance.intValue();
                text = replace.string;
            });
        
        data.addQuickFix {
            description = "Invert 'if' 'else' statement";
            change = change;
            selection = DefaultRegion(ifStmt.startIndex.intValue());
        };
    }
    
    Boolean isElseOnOwnLine(CommonDocument doc, Node ifBlock, Node elseBlock) 
            => doc.getLineOfOffset(ifBlock.stopIndex.intValue())
                != doc.getLineOfOffset(elseBlock.startIndex.intValue());
    
    String addEnclosingBraces(String s, String baseIndent, String _indent, String delim) {
        assert(exists first = s.first);
        if (first != '{') {
            return "{" 
                    + delim + baseIndent + _indent 
                    + indent(s, _indent, delim) + delim + baseIndent 
                    + "}";
        }
        else {
            return s;
        }
    }
    
    String indent(String s, String indentation, String delim) 
            => nativeString(s)
                .replaceAll(delim + "(\\s*)", delim + "$1" + indentation);
    
   String invertTerm(CommonDocument doc, Tree.Term? term) {
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
               return "!" + doc.getNodeText(term);
           }
       }
       case (is Tree.NotOp) {
           return doc.getNodeText(term.term);
       }
       case (is Tree.EqualOp) {
           return doc.getNodeText(term.leftTerm) + "!=" + 
                   doc.getNodeText(term.rightTerm);
       }
       case (is Tree.NotEqualOp) {
           return doc.getNodeText(term.leftTerm) + "=" + 
                   doc.getNodeText(term.rightTerm);
       }
       case (is Tree.SmallerOp) {
           return doc.getNodeText(term.leftTerm) + ">=" + 
                   doc.getNodeText(term.rightTerm);
       }
       case (is Tree.SmallAsOp) {
           return doc.getNodeText(term.leftTerm) + ">" + 
                   doc.getNodeText(term.rightTerm);
       }
       case (is Tree.LargerOp) {
           return doc.getNodeText(term.leftTerm) + "<=" + 
                   doc.getNodeText(term.rightTerm);
       }
       case (is Tree.LargeAsOp) {
           return doc.getNodeText(term.leftTerm) + "<" + 
                   doc.getNodeText(term.rightTerm);
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
               return "!" + doc.getNodeText(term);
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
           return "!(" + doc.getNodeText(term) + ")";
       }
       else {
           return "!" + doc.getNodeText(term);
       }
   }
   
   String invertCondition(CommonDocument doc, Tree.Condition? ifCondition) {
       switch(ifCondition)
       case (is Tree.BooleanCondition) {
           Tree.Term? term = ifCondition.expression.term;
           if (is Tree.NotOp term, is Tree.Expression e = term.term) {
               //special case for eliminating toplevel parens
               return doc.getNodeText(e.term);
           }
           else {
               return invertTerm(doc, term);
           }
       }
       case (is Tree.ExistsOrNonemptyCondition|Tree.IsCondition) {
           value negated =
               switch (ifCondition)
               case (is Tree.ExistsOrNonemptyCondition) 
                    ifCondition.not
               case (is Tree.IsCondition) 
                    ifCondition.not;
           return negated
               then doc.getNodeText(ifCondition)[1...].trimmed 
               else "!" + doc.getNodeText(ifCondition).trimmed;
       }
       else {
           return "";
       }
   }
   
}



