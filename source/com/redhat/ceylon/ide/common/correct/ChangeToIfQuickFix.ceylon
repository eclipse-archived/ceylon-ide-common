import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    InsertEdit
}

shared object changeToIfQuickFix {
 
    shared void addChangeToIfProposal(QuickFixData data, Tree.Statement? statement) {
        if (is Tree.Assertion statement, 
            exists conditionList = statement.conditionList) {
            object findBodyVisitor extends Visitor() {
                shared variable Tree.Body? result = null;
                
                shared actual void visit(Tree.Body that) {
                    if (that.statements.contains(statement)) {
                        result = that;
                    } else {
                        super.visit(that);
                    }
                }
            }
            
            findBodyVisitor.visit(data.rootNode);
            
            if (exists body = findBodyVisitor.result) {
                value statements = body.statements;
                value last = statements.get(statements.size()-1);
                value isLast = statement == last;
                value change 
                        = platformServices.document.createTextChange {
                    name = "Change Assert To If";
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
                value doc = change.document;
                value newline = doc.defaultLineDelimiter;
                value indent = doc.getIndent(last);
                value begin = statement.startIndex.intValue();
                value end = conditionList.startIndex.intValue();
                
                change.addEdit(ReplaceEdit {
                    start = begin;
                    length = end - begin;
                    text = "if ";
                });
                change.addEdit(ReplaceEdit {
                    start = statement.endIndex.intValue() - 1;
                    length = 1;
                    text = if (isLast) then " {}" else " {";
                });
                
                //TODO: this is wrong, need to look for lines, not statements!
                variable value i = statements.indexOf(statement) + 1;
                while (i < statements.size()) {
                    change.addEdit(InsertEdit {
                        start = statements.get(i).startIndex.intValue();
                        text = platformServices.document.defaultIndent;
                    }
                    );
                    i++;
                }
                
                if (!isLast) {
                    change.addEdit(InsertEdit {
                        start = last.endIndex.intValue();
                        text = newline + indent + "}";
                    });
                }
                
                change.addEdit(InsertEdit {
                    start = last.endIndex.intValue();
                    text = newline + indent + "else {" + newline 
                        + indent + platformServices.document.defaultIndent
                        + "assert (false);" + newline + indent + "}";
                });
                
                data.addQuickFix {
                    description = "Change 'assert' to 'if'";
                    change = change;
                    selection = DefaultRegion {
                        start = statement.endIndex.intValue() - 3;
                        length = 0;
                    };
                };   
            }
        }
    }
}
