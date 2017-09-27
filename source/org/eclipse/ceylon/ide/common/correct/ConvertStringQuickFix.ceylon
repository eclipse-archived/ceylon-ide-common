import ceylon.collection {
    MutableList,
    ArrayList
}
            
import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    CommonDocument,
    InsertEdit,
    DeleteEdit
}

shared object convertStringQuickFix {
    
    shared void addConvertToVerbatimProposal(QuickFixData data) {
        if (is Tree.StringLiteral literal = data.node) {
            value token = literal.token;
            if (token.type==CeylonLexer.astringLiteral || 
                token.type==CeylonLexer.stringLiteral) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Convert to Verbatim String";
                    input = data.phasedUnit;
                };
                change.addEdit(ReplaceEdit {
                    start = literal.startIndex.intValue();
                    length = literal.distance.intValue();
                    text = getConvertedText {
                        text = "\"\"\"``literal.text``\"\"\"";
                        indentation = token.charPositionInLine + 3;
                        doc = change.document;
                    };
                });
                
                data.addQuickFix("Convert to verbatim string", change);
            }
        }
    }
    
    shared void addConvertFromVerbatimProposal(QuickFixData data) {
        if (is Tree.StringLiteral literal = data.node) {
            value token = literal.token;
            if (token.type==CeylonLexer.averbatimString || 
                token.type==CeylonLexer.verbatimString) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Convert to Ordinary String";
                    input = data.phasedUnit;
                };
                value escaped 
                        = literal.text
                            .replace("\\", "\\\\")
                            .replace("\"", "\\\"")
                            .replace("`", "\\`");
                change.addEdit(ReplaceEdit {
                    start = literal.startIndex.intValue();
                    length = literal.distance.intValue();
                    text = getConvertedText {
                        text = "\"``escaped``\"";
                        indentation = token.charPositionInLine + 1;
                        doc = change.document;
                    };
                });
                
                data.addQuickFix("Convert to ordinary string", change);
            }
        }
    }
    
    shared void addConvertToConcatenationProposal(QuickFixData data) {
        variable Tree.StringTemplate? result = null;
        value node = data.node;
        
        object extends Visitor() {
            shared actual void visit(Tree.StringTemplate that) {
                if (that.startIndex.intValue() 
                        <= node.startIndex.intValue(),
                    that.endIndex.intValue() 
                        >= node.endIndex.intValue()) {
                    result = that;
                }
                
                super.visit(that);
            }
        }.visit(data.rootNode);
        
        if (exists template = result) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Concatenation";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value st = node.unit.stringType;
            value literals = template.stringLiterals;
            value expressions = template.expressions;
            variable Integer i = 0;
            
            while (i < literals.size()) {
                value s = literals.get(i);
                if (s.text.empty) {
                    if (i > 0, i < literals.size() - 1) {
                        change.addEdit(ReplaceEdit {
                            start = s.startIndex.intValue();
                            length = s.distance.intValue();
                            text = " + ";
                        });
                    } else {
                        change.addEdit(DeleteEdit {
                            start = s.startIndex.intValue();
                            length = s.distance.intValue();
                        });
                    }
                } else {
                    Integer? stt = s.token.type;
                    if (exists stt, stt in [CeylonLexer.stringEnd, CeylonLexer.stringMid]) {
                        change.addEdit(ReplaceEdit {
                            start = s.startIndex.intValue();
                            length = 2;
                            text = " + \"";
                        });
                    }
                    
                    if (exists stt, stt in [CeylonLexer.stringStart, CeylonLexer.stringMid]) {
                        change.addEdit(ReplaceEdit {
                            start = s.endIndex.intValue() - 2;
                            length = 2;
                            text = "\" + ";
                        });
                    }
                }
                
                if (i < expressions.size()) {
                    value e = expressions.get(i);
                    if (e.term is Tree.OperatorExpression) {
                        change.addEdit(InsertEdit {
                            start = e.startIndex.intValue();
                            text = "(";
                        });
                        change.addEdit(InsertEdit {
                            start = e.endIndex.intValue();
                            text = ")";
                        });
                    }
                    
                    if (!e.typeModel.isSubtypeOf(st)) {
                        change.addEdit(InsertEdit {
                            start = e.endIndex.intValue();
                            text = ".string";
                        });
                    }
                }
                
                i++;
            }
            
            data.addQuickFix("Convert to string concatenation", change);
        }
    }
    
    shared void addConvertToInterpolationProposal(QuickFixData data) {
        variable Tree.SumOp? result = null;
        value node = data.node;
        
        object extends Visitor() {
            shared actual void visit(Tree.SumOp that) {
                if (that.startIndex.intValue() 
                        <= node.startIndex.intValue(),
                    that.endIndex.intValue() 
                        >= node.endIndex.intValue(),
                    exists model = that.typeModel,
                    model.isString()) {
                    
                    result = that;
                }
                
                super.visit(that);
            }
        }.visit(data.rootNode);
        
        if (exists sum = result) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Convert to Interpolation";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            value terms = flatten(sum);
            value lt = terms.get(0);
            value rt = terms.get(terms.size - 1);
            variable Boolean expectingLiteral 
                    = lt is Tree.StringLiteral|Tree.StringTemplate;
            
            if (exists lt, !expectingLiteral) {
                change.addEdit(InsertEdit {
                    start = lt.startIndex.intValue();
                    text = """"``""";
                });
            }

            variable Integer i = 0;
            for (term in terms) {
                if (i > 0) {
                    assert(exists previous = terms.get(i - 1));
                    value from = previous.endIndex.intValue();
                    value to = term.startIndex.intValue();
                    change.addEdit(DeleteEdit(from, to - from));
                }
                if (expectingLiteral, 
                    !term is Tree.StringLiteral|Tree.StringTemplate) {
                    change.addEdit(InsertEdit {
                        start = term.startIndex.intValue();
                        text = """````""";
                    });
                    expectingLiteral = false;
                }
                if (expectingLiteral) {
                    if (i > 0) {
                        change.addEdit(ReplaceEdit {
                            start = term.startIndex.intValue();
                            length = 1;
                            text = """``""";
                        });
                    }
                    
                    if (i < terms.size - 1) {
                        change.addEdit(ReplaceEdit {
                            start = term.endIndex.intValue() - 1;
                            length = 1;
                            text = """``""";
                        });
                    }
                    expectingLiteral = false;
                } else {
                    if (is Tree.QualifiedMemberExpression term,
                           term.declaration.name == "string") {
                        value from = term.memberOperator.startIndex.intValue();
                        value to = term.identifier.endIndex.intValue();
                        change.addEdit(DeleteEdit(from, to - from));
                    }
                    expectingLiteral = true;
                }
                i++;
            }
            
            if (expectingLiteral, exists rt) {
                change.addEdit(InsertEdit {
                    start = rt.endIndex.intValue();
                    text = """``"""";
                });
            }
            data.addQuickFix("Convert to string interpolation", change);
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

    String getConvertedText(String text, Integer indentation, 
            CommonDocument doc) {
        value result = StringBuilder();
        for (line in text.lines) {
            if (result.size == 0) {
                result.append(line.string);
            }
            else {
                variable Integer i = 0;
                while (i < indentation) {
                    result.append(" ");
                    i++;
                }
                result.append(line.string);
            }
            result.append(doc.defaultLineDelimiter);
        }
        result.deleteTerminal(1);
        return result.string;
    }
}
