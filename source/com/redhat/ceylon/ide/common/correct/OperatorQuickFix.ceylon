import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}

import org.antlr.runtime {
    CommonToken
}

shared interface OperatorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
 
    shared void addSwapBinaryOperandsProposal(Data data, IFile file, Tree.BinaryOperatorExpression? boe) {
        if (exists boe,
            exists lt = boe.leftTerm,
            exists rt = boe.rightTerm) {
            
            value change = newTextChange("Swap Operands", file);
            initMultiEditChange(change);
            value lto = lt.startIndex.intValue();
            value ltl = lt.distance.intValue();
            value rto = rt.startIndex.intValue();
            value rtl = rt.distance.intValue();
            value doc = getDocumentForChange(change);
            
            addEditToChange(change, newReplaceEdit(lto, ltl, getDocContent(doc, rto, rtl)));
            addEditToChange(change, newReplaceEdit(rto, rtl, getDocContent(doc, lto, ltl)));
            newProposal(data, "Swap operands of " + boe.mainToken.text + " expression", change);
        }
    }
    
    shared void addReverseOperatorProposal(Data data, IFile file, Tree.BinaryOperatorExpression? boe) {
        if (is Tree.ComparisonOp boe) {
            value change = newTextChange("Reverse Operator", file);
            initMultiEditChange(change);

            if (exists lt = boe.leftTerm,
                exists rt = boe.rightTerm) {
                
                value lto = lt.startIndex.intValue();
                value ltl = lt.distance.intValue();
                value rto = rt.startIndex.intValue();
                value rtl = rt.distance.intValue();
                assert (is CommonToken op = boe.mainToken);
                value ot = op.text;
                value iot = reversed(ot);
                addEditToChange(change, newReplaceEdit(op.startIndex, ot.size, iot));

                value document = getDocumentForChange(change);
                addEditToChange(change, newReplaceEdit(lto, ltl, getDocContent(document, rto, rtl)));
                addEditToChange(change, newReplaceEdit(rto, rtl, getDocContent(document, lto, ltl)));
                
                newProposal(data, "Convert " + ot + " to " + iot, change);
            }
        }
    }
    
    shared void addInvertOperatorProposal(Data data, IFile file, Tree.BinaryOperatorExpression? boe) {
        if (is Tree.ComparisonOp|Tree.LogicalOp boe) {
            value change = newTextChange("Invert Operator", file);
            initMultiEditChange(change);

            if (exists lt = boe.leftTerm,
                exists rt = boe.rightTerm) {

                assert (is CommonToken op = boe.mainToken);
                value ot = op.text;
                value iot = inverted(ot);
                addEditToChange(change, newReplaceEdit(op.startIndex, ot.size, iot));
                addEditToChange(change, newInsertEdit(boe.startIndex.intValue(), "!("));
                addEditToChange(change, newInsertEdit(boe.endIndex.intValue(), ")"));
                
                if (is Tree.LogicalOp boe) {
                    // TODO !!!!
                    //invertTerm(boe.leftTerm, change);
                    //invertTerm(boe.rightTerm, change);
                }
                
                newProposal(data, "Convert " + ot + " to " + iot, change);
            }
        }
    }

    String inverted(String ot) {
        switch (ot)
        case (">") {
            return "<=";
        }
        case (">=") {
            return "<";
        }
        case ("<") {
            return ">=";
        }
        case ("<=") {
            return ">";
        }
        case ("||") {
            return "&&";
        }
        case ("&&") {
            return "||";
        }
        else {
            return ot;
        }
    }

    String reversed(String ot) {
        switch (ot)
        case (">") {
            return "<";
        }
        case (">=") {
            return "<=";
        }
        case ("<") {
            return ">";
        }
        case ("<=") {
            return ">=";
        }
        else {
            return ot;
        }
    }
    
    shared void addParenthesesProposals(Data data, IFile file, Tree.OperatorExpression? oe) {
        Node? node;
        if (is Tree.ArgumentList argList = data.node) {
            object findInvocationVisitor extends Visitor() {
                variable Tree.InvocationExpression? current = null;
                shared variable Tree.InvocationExpression? result = null;
                
                shared actual void visit(Tree.InvocationExpression that) {
                    value old = current;
                    current = that;
                    super.visit(that);
                    current = old;
                }
                
                shared actual void visit(Tree.ArgumentList that) {
                    if (argList == that) {
                        result = current;
                    } else {
                        super.visit(that);
                    }
                }
            }
            findInvocationVisitor.visit(data.rootNode);
            node = findInvocationVisitor.result;
        }
        else {
            object ignoreLeftSideVisitor extends Visitor() {
                variable shared Node? result = null;
                shared actual void visit(Tree.SpecifierStatement specifierStatement) {
                    //ignore LHSs of assignments
                    if (exists rhs = specifierStatement.specifierExpression) {
                        rhs.visit(this);
                    }
                }
                shared actual void visitAny(Node node) {
                    if (node==data.node) {
                        result = node;
                    }
                    else {
                        super.visitAny(node);
                    }
                }
            }
            ignoreLeftSideVisitor.visit(data.rootNode);
            node = ignoreLeftSideVisitor.result;
        }
        
        if (is Tree.Expression n = node) {
            addRemoveParenthesesProposal(data, file, n);
        } else if (is Tree.Term n = node) {
            addAddParenthesesProposal(data, file, n);
            if (exists oe, oe != n) {
                addAddParenthesesProposal(data, file, oe);
            }
        }
    }
    
    void addAddParenthesesProposal(Data data, IFile file, Node node) {
        variable String desc;
        if (is Tree.OperatorExpression node) {
            desc = node.mainToken.text + " expression";
        } else if (is Tree.QualifiedMemberOrTypeExpression node) {
            desc = "member reference";
        } else if (is Tree.BaseMemberOrTypeExpression node) {
            desc = "base reference";
        } else if (is Tree.Literal node) {
            desc = "literal";
        } else if (is Tree.InvocationExpression node) {
            desc = "invocation";
        } else {
            desc = "expression";
        }
        
        value change = newTextChange("Add Parentheses", file);
        initMultiEditChange(change);
        addEditToChange(change, newInsertEdit(node.startIndex.intValue(), "("));
        addEditToChange(change, newInsertEdit(node.endIndex.intValue(), ")"));
        
        newProposal(data, "Parenthesize " + desc, change);
    }
    
    void addRemoveParenthesesProposal(Data data, IFile file, Node node) {
        if (exists token = node.token,
            exists endToken = node.endToken,
            token.type == CeylonLexer.\iLPAREN,
            endToken.type == CeylonLexer.\iRPAREN) {
            
            value change = newTextChange("Remove Parentheses", file);
            initMultiEditChange(change);
            addEditToChange(change, newDeleteEdit(node.startIndex.intValue(), 1));
            addEditToChange(change, newDeleteEdit(node.endIndex.intValue() - 1, 1));
            
            newProposal(data, "Remove parentheses", change);
        }
    }
}
