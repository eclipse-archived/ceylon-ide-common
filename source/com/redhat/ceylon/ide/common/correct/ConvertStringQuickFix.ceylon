import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import ceylon.interop.java {
    javaString
}
import ceylon.collection {
    MutableList,
    ArrayList
}

shared interface ConvertStringQuickFix<IFile, IDocument, InsertEdit, TextEdit, TextChange, Region, Project, Data, CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
    
    shared void addConvertToVerbatimProposal(Data data, IFile file) {
        if (is Tree.StringLiteral literal = data.node) {
            value token = literal.token;
            if (token.type==CeylonLexer.\iASTRING_LITERAL
                        || token.type==CeylonLexer.\iSTRING_LITERAL) {
                
                value text = "\"\"\"" + literal.text + "\"\"\"";
                value offset = literal.startIndex.intValue();
                value length = literal.distance.intValue();
                value change = newTextChange("Convert to Verbatim String", file);
                value doc = getDocumentForChange(change);
                value reindented = getConvertedText(text, token.charPositionInLine + 3, doc);
                addEditToChange(change, newReplaceEdit(offset, length, reindented));
                
                newProposal(data, "Convert to verbatim string", change);
            }
        }
    }
    
    shared void addConvertFromVerbatimProposal(Data data, IFile file) {
        if (is Tree.StringLiteral literal = data.node) {
            value token = literal.token;
            if (token.type==CeylonLexer.\iAVERBATIM_STRING || token.type==CeylonLexer.\iVERBATIM_STRING) {
                value text = "\"" + literal.text.replace("\\", "\\\\").replace("\"", "\\\"").replace("`", "\\`") + "\"";
                value offset = literal.startIndex.intValue();
                value length = literal.distance.intValue();
                value change = newTextChange("Convert to Ordinary String", file);
                value doc = getDocumentForChange(change);
                value reindented = getConvertedText(text, token.charPositionInLine + 1, doc);
                addEditToChange(change, newReplaceEdit(offset, length, reindented));
                
                newProposal(data, "Convert to ordinary string", change);
            }
        }
    }
    
    shared void addConvertToConcatenationProposal(Data data, IFile file) {
        variable Tree.StringTemplate? result = null;
        value node = data.node;
        
        object extends Visitor() {
            shared actual void visit(Tree.StringTemplate that) {
                if (that.startIndex.intValue() <= node.startIndex.intValue(),
                    that.endIndex.intValue() >= node.endIndex.intValue()) {
                    result = that;
                }
                
                super.visit(that);
            }
        }.visit(data.rootNode);
        
        if (exists template = result) {
            value change = newTextChange("Convert to Concatenation", file);
            initMultiEditChange(change);
            value st = node.unit.stringType;
            value literals = template.stringLiterals;
            value expressions = template.expressions;
            variable Integer i = 0;
            
            while (i < literals.size()) {
                value s = literals.get(i);
                if (s.text.empty) {
                    if (i > 0, i < literals.size() - 1) {
                        addEditToChange(change, newReplaceEdit(s.startIndex.intValue(),
                                s.distance.intValue(), " + "));
                    } else {
                        addEditToChange(change, newDeleteEdit(s.startIndex.intValue(),
                                s.distance.intValue()));
                    }
                } else {
                    value stt = s.token.type;
                    if (stt in [CeylonLexer.\iSTRING_END, CeylonLexer.\iSTRING_MID]) {
                        addEditToChange(change, newReplaceEdit(s.startIndex.intValue(), 2, " + \""));
                    }
                    
                    if (stt in [CeylonLexer.\iSTRING_START, CeylonLexer.\iSTRING_MID]) {
                        addEditToChange(change, newReplaceEdit(s.endIndex.intValue() - 2, 2, "\" + "));
                    }
                }
                
                if (i < expressions.size()) {
                    value e = expressions.get(i);
                    if (e.term is Tree.OperatorExpression) {
                        addEditToChange(change, newInsertEdit(e.startIndex.intValue(), "("));
                        addEditToChange(change, newInsertEdit(e.endIndex.intValue(), ")"));
                    }
                    
                    if (!e.typeModel.isSubtypeOf(st)) {
                        addEditToChange(change, newInsertEdit(e.endIndex.intValue(), ".string"));
                    }
                }
                
                i++;
            }
            
            newProposal(data, "Convert to string concatenation", change);
        }
    }
    
    shared void addConvertToInterpolationProposal(Data data, IFile file) {
        variable Tree.SumOp? result = null;
        value node = data.node;
        
        object extends Visitor() {
            shared actual void visit(Tree.SumOp that) {
                if (that.startIndex.intValue() <= node.startIndex.intValue(),
                    that.endIndex.intValue() >= node.endIndex.intValue(),
                    exists model = that.typeModel,
                    model.isString()) {
                    
                    result = that;
                }
                
                super.visit(that);
            }
        }.visit(data.rootNode);
        
        if (exists sum = result) {
            value change = newTextChange("Convert to Interpolation", file);
            initMultiEditChange(change);
            value terms = flatten(sum);
            value lt = terms.get(0);
            value rt = terms.get(terms.size - 1);
            variable Boolean expectingLiteral = lt is Tree.StringLiteral || lt is Tree.StringTemplate;
            
            if (exists lt, !expectingLiteral) {
                addEditToChange(change, newInsertEdit(lt.startIndex.intValue(), """"``"""));
            }

            variable Integer i = 0;
            for (term in terms) {
                if (i > 0) {
                    assert(exists previous = terms.get(i - 1));
                    value from = previous.endIndex.intValue();
                    value to = term.startIndex.intValue();
                    addEditToChange(change, newDeleteEdit(from, to - from));
                }
                if (expectingLiteral, !(term is Tree.StringLiteral || term is Tree.StringTemplate)) {
                    addEditToChange(change, newInsertEdit(term.startIndex.intValue(), """````"""));
                    expectingLiteral = false;
                }
                if (expectingLiteral) {
                    if (i > 0) {
                        addEditToChange(change, newReplaceEdit(term.startIndex.intValue(), 1, """``"""));
                    }
                    
                    if (i < terms.size - 1) {
                        addEditToChange(change, newReplaceEdit(term.endIndex.intValue() - 1, 1, """``"""));
                    }
                    expectingLiteral = false;
                } else {
                    if (is Tree.QualifiedMemberExpression lrt = term,
                           lrt.declaration.name == "string") {
                        value from = lrt.memberOperator.startIndex.intValue();
                        value to = lrt.identifier.endIndex.intValue();
                        addEditToChange(change, newDeleteEdit(from, to - from));
                    }
                    expectingLiteral = true;
                }
                i++;
            }
            
            if (expectingLiteral, exists rt) {
                addEditToChange(change, newInsertEdit(rt.endIndex.intValue(), """``""""));
            }
            newProposal(data, "Convert to string interpolation", change);
        }
    }
    
    MutableList<Tree.Term> flatten(Tree.SumOp sum) {
        value lt = sum.leftTerm;
        value rt = sum.rightTerm;
        MutableList<Tree.Term> result;
        
        if (is Tree.SumOp lt) {
            result = flatten(lt);
            result.add(rt);
        } else {
            result = ArrayList<Tree.Term>();
            result.add(lt);
            result.add(rt);
        }
        
        return result;
    }

    String getConvertedText(String text, Integer indentation, IDocument doc) {
        value result = StringBuilder();
        for (line in javaString(text).split("\n|\r\n?").iterable.coalesced) {
            if (result.size == 0) {
                result.append(line.string);
            } else {
                variable Integer i = 0;
                while (i < indentation) {
                    result.append(" ");
                    i++;
                }
                
                result.append(line.string);
            }
            
            result.append(indents.getDefaultLineDelimiter(doc));
        }
        
        result.deleteTerminal(1);
        return result.string;
    }
}
