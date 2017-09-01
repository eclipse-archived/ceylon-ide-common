import com.redhat.ceylon.compiler.typechecker.parser {
    CL=CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    TextChange,
    InsertEdit,
    DefaultDocument
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

import java.util {
    List
}

import org.antlr.runtime {
    Token,
    CommonToken
}
import java.lang {
    overloaded
}

shared abstract class AbstractTerminateStatementAction<Document=DefaultDocument>()
        given Document satisfies CommonDocument {
    
    shared formal [Tree.CompilationUnit, List<CommonToken>] parse(Document doc);

    variable Integer? newCursorPosition = null;
    
    shared DefaultRegion? terminateStatement(Document doc, Integer line) {
        terminateWithSemicolon(doc, line);
        variable Boolean changed = true;
        variable Integer count = 0;
        
        while (changed && count < 5) {
            changed = terminateWithBrace(doc, line);
            count++;
        }
        
        return if (exists pos = newCursorPosition)
               then DefaultRegion(pos, 0)
               else null;
    }
    
    Boolean terminateWithBrace(Document doc, Integer line) {
        value change 
                = platformServices.document.createTextChange(
                    "Terminate Statement", doc);
        change.initMultiEdit();
        let ([rootNode, tokens] = parse(doc));
        value lineRegion = doc.getLineRegion(line);
        value lineText = doc.getLineContent(line);
        value startOfCodeInLine 
                = getCodeStart(lineRegion, lineText, tokens);
        value endOfCodeInLine 
                = getCodeEnd(lineRegion, lineText, tokens);
        
        TerminateWithBraceProcessor {
            startOfCodeInLine = startOfCodeInLine;
            endOfCodeInLine = endOfCodeInLine;
            change = change;
        }.visit(rootNode);
            
        if (change.hasEdits) {
            change.apply();
            return true;
        }
        else {
            return false;
        }
    }

    Boolean terminateWithSemicolon(Document doc, Integer line) {
        value change 
                = platformServices.document.createTextChange(
                    "Terminate Statement", doc);
        change.initMultiEdit();
        let ([rootNode, tokens] = parse(doc));
        value lineRegion = doc.getLineRegion(line);
        value lineText = doc.getLineContent(line);
        value endOfCodeInLine 
                = getCodeEnd(lineRegion, lineText, tokens);

        if (doc.getChar(endOfCodeInLine) != ';') {
            TerminateWithSemicolonProcessor {
                endOfCodeInLine = endOfCodeInLine;
                change = change;
            }.visit(rootNode);
            
            if (change.hasEdits) {
                change.apply();
                return true;
            }
            else {
                return false;
            }
        }
        else {
            return false;
        }
    }

    Integer getCodeEnd(DefaultRegion li, String lineText, 
        List<CommonToken> tokens) {
        variable value j = lineText.size - 1;
        while (j >= 0) {
            value offset = li.start + j;
            if (!skipToken(tokens, offset)) {
                break;
            }
            
            j--;
        }
        
        value endOfCodeInLine = li.start + j;
        return endOfCodeInLine;
    }
    
    Integer getCodeStart(DefaultRegion li, String lineText, 
        List<CommonToken> tokens) {
        variable value k = 0;
        while (k < lineText.size) {
            value offset = li.start + k;
            if (!skipToken(tokens, offset)) {
                break;
            }
            k++;
        }
        
        value startOfCodeInLine = li.start + k;
        return startOfCodeInLine;
    }


    class TerminateWithSemicolonProcessor(
        Integer endOfCodeInLine,
        TextChange change
    ) extends Visitor() {
        overloaded
        shared actual void visit(Tree.Annotation that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }

        overloaded
        shared actual void visit(Tree.StaticType that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }

        overloaded
        shared actual void visit(Tree.Expression that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }
        
        Boolean terminatedInLine(Node? node) {
            return if (exists node, 
                node.startIndex.intValue() 
                        <= endOfCodeInLine)
                    then true else false;
        }

        overloaded
        shared actual void visit(Tree.IfClause that) {
            super.visit(that);
            if (missingBlock(that.block), 
                terminatedInLine(that.conditionList)) {
                terminateWithParensAndBraces(that, 
                    that.conditionList);
            }
        }

        overloaded
        shared actual void visit(Tree.ElseClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBraces(that);
            }
        }

        overloaded
        shared actual void visit(Tree.ForClause that) {
            super.visit(that);
            if (missingBlock(that.block), 
                terminatedInLine(that.forIterator)) {
                terminateWithParensAndBraces(that, 
                    that.forIterator);
            }
        }

        overloaded
        shared actual void visit(Tree.WhileClause that) {
            super.visit(that);
            if (missingBlock(that.block), 
                terminatedInLine(that.conditionList)) {
                terminateWithParensAndBraces(that, 
                    that.conditionList);
            }
        }

        overloaded
        shared actual void visit(Tree.CaseClause that) {
            super.visit(that);
            if (missingBlock(that.block), 
                terminatedInLine(that.caseItem)) {
                terminateWithParensAndBraces(that, 
                    that.caseItem);
            }
        }

        overloaded
        shared actual void visit(Tree.TryClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBraces(that);
            }
        }

        overloaded
        shared actual void visit(Tree.CatchClause that) {
            super.visit(that);
            if (missingBlock(that.block), 
                terminatedInLine(that.catchVariable)) {
                terminateWithParensAndBraces(that, 
                    that.catchVariable);
            }
        }

        overloaded
        shared actual void visit(Tree.FinallyClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBraces(that);
            }
        }

        overloaded
        shared actual void visit(Tree.StatementOrArgument that) {
            if (that is Tree.ExecutableStatement
                    && !(that is Tree.ControlStatement)
                    || that is Tree.AttributeDeclaration 
                             | Tree.ImportModule
                             | Tree.TypeAliasDeclaration
                             | Tree.SpecifiedArgument) {
                terminateWithSemicolon(that);
            }
            
            if (is Tree.MethodDeclaration that) {
                if (!that.specifierExpression exists) {
                    value pl = that.parameterLists;
                    if (that.identifier exists, 
                        terminatedInLine(that.identifier)) {
                        terminateWithParensAndBraces(that,
                            if (pl.empty) then null 
                                else pl.get(pl.size() - 1));
                    }
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            if (is Tree.Constructor that) {
                if (!that.block exists) {
                    terminateWithParensAndBraces(that, 
                        that.parameterList);
                }
            }
            if (is Tree.Enumerated that) {
                if (!that.block exists) {
                    terminateWithBraces(that);
                }
            }
            
            if (is Tree.ClassDeclaration that) {
                if (!that.classSpecifier exists) {
                    terminateWithParensAndBraces(that, 
                        that.parameterList);
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            if (is Tree.InterfaceDeclaration that) {
                if (!that.typeSpecifier exists) {
                    terminateWithBraces(that);
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            super.visit(that);
        }
        
        void terminateWithParensAndBraces(Node that, Node? subnode) {
            try {
                if (withinLine(that)) {
                    value startIndex 
                            = subnode?.startIndex?.intValue()
                                else endOfCodeInLine + 1;
                    if (startIndex > endOfCodeInLine) {
                        if (!change.hasEdits) {
                            change.addEdit(InsertEdit {
                                start = endOfCodeInLine + 1;
                                text = "() {}";
                            });
                            newCursorPosition 
                                    = endOfCodeInLine + 1 + 4;
                        }
                    } else {
                        assert(exists subnode);
                        Token? et = that.endToken;
                        Token? set = subnode.endToken;
                        if (!set exists
                            || (set?.type else 0)!=CL.rparen
                            || subnode.stopIndex.intValue() 
                                    > endOfCodeInLine) {
                            
                            if (!change.hasEdits) {
                                change.addEdit(InsertEdit {
                                    start = endOfCodeInLine + 1;
                                    text = ") {}";
                                });
                                newCursorPosition 
                                        = endOfCodeInLine + 1 + 3;
                            }
                        } else if (!et exists
                            || (et?.type else 0)!=CL.rbrace
                            || that.stopIndex.intValue() > endOfCodeInLine) {
                            
                            if (!change.hasEdits) {
                                change.addEdit(InsertEdit {
                                    start = endOfCodeInLine + 1;
                                    text = " {}";
                                });
                                newCursorPosition 
                                        = endOfCodeInLine + 1 + 2;
                            }
                        }
                    }
                }
            } catch (e) {
                e.printStackTrace();
            }
        }
        
        void terminateWithBraces(Node that) {
            try {
                if (withinLine(that)) {
                    Token? et = that.endToken;
                    if (!et exists
                        || (et?.type else 0)!=CL.semicolon
                        && (et?.type else 0)!=CL.rbrace
                        || that.stopIndex.intValue() 
                                > endOfCodeInLine) {
                        
                        if (!change.hasEdits) {
                            change.addEdit(InsertEdit {
                                start = endOfCodeInLine + 1;
                                text = " {}";
                            });
                            newCursorPosition 
                                    = endOfCodeInLine + 1 + 2;
                        }
                    }
                }
            } catch (e) {
                e.printStackTrace();
            }
        }
        
        void terminateWithSemicolon(Node that) {
            try {
                if (withinLine(that)) {
                    Token? et = that.endToken;
                    if (!et exists
                        || (et?.type else 0)!=CL.semicolon
                        || that.stopIndex.intValue() 
                                > endOfCodeInLine) {
                        
                        if (!change.hasEdits) {
                            change.addEdit(InsertEdit {
                                start = endOfCodeInLine + 1;
                                text = ";";
                            });
                            newCursorPosition 
                                    = endOfCodeInLine + 2;
                        }
                    }
                }
            } catch (e) {
                e.printStackTrace();
            }
        }
        
        Boolean withinLine(Node that) 
                => if (exists start = that.startIndex,
                       exists stop = that.stopIndex)
                then start.intValue() <= endOfCodeInLine
                  && stop.intValue() >= endOfCodeInLine
                else false;
        
        Boolean missingBlock(Tree.Block? block) 
                => if (exists text = block?.mainToken?.text)
                then text.startsWith("<missing") 
                else true;
    }


    class TerminateWithBraceProcessor(
        Integer startOfCodeInLine,
        Integer endOfCodeInLine,
        TextChange change
    ) extends Visitor() {

        overloaded
        shared actual void visit(Tree.Expression that) {
            super.visit(that);
            if (exists start = that.startIndex, 
                exists stop = that.stopIndex,
                stop.intValue() <= endOfCodeInLine &&
                start.intValue() >= startOfCodeInLine,
                exists st = that.mainToken,
                st.type == CL.lparen,
                (that.mainEndToken?.type else -1)!=CL.rparen,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit {
                    start = that.endIndex.intValue();
                    text = ")";
                });
            }
        }

        overloaded
        shared actual void visit(Tree.ParameterList that) {
            super.visit(that);
            terminate(that, CL.rparen, ")");
        }

        overloaded
        shared actual void visit(Tree.IndexExpression that) {
            super.visit(that);
            terminate(that, CL.rbracket, "]");
        }

        overloaded
        shared actual void visit(Tree.TypeParameterList that) {
            super.visit(that);
            terminate(that, CL.largerOp, ">");
        }

        overloaded
        shared actual void visit(Tree.TypeArgumentList that) {
            super.visit(that);
            terminate(that, CL.largerOp, ">");
        }

        overloaded
        shared actual void visit(Tree.PositionalArgumentList that) {
            super.visit(that);
            if (exists t = that.token, t.type == CL.lparen) {
                terminate(that, CL.rparen, ")");
            }
        }

        overloaded
        shared actual void visit(Tree.NamedArgumentList that) {
            super.visit(that);
            terminate(that, CL.rbrace, " }");
        }

        overloaded
        shared actual void visit(Tree.SequenceEnumeration that) {
            super.visit(that);
            terminate(that, CL.rbrace, " }");
        }

        overloaded
        shared actual void visit(Tree.IterableType that) {
            super.visit(that);
            terminate(that, CL.rbrace, "}");
        }

        overloaded
        shared actual void visit(Tree.Tuple that) {
            super.visit(that);
            terminate(that, CL.rbracket, "]");
        }

        overloaded
        shared actual void visit(Tree.TupleType that) {
            super.visit(that);
            terminate(that, CL.rbracket, "]");
        }

        overloaded
        shared actual void visit(Tree.ConditionList that) {
            super.visit(that);
            if (!that.mainToken.text.startsWith("<missing ")) {
                terminate(that, CL.rparen, ")");
            }
        }

        overloaded
        shared actual void visit(Tree.ForIterator that) {
            super.visit(that);
            if (!that.mainToken.text.startsWith("<missing ")) {
                terminate(that, CL.rparen, ")");
            }
        }

        overloaded
        shared actual void visit(Tree.ImportMemberOrTypeList that) {
            super.visit(that);
            terminate(that, CL.rbrace, " }");
        }

        overloaded
        shared actual void visit(Tree.Import that) {
            if (!that.importMemberOrTypeList exists
                || that.importMemberOrTypeList.mainToken
                    .text.startsWith("<missing "),
                !change.hasEdits,
                exists ip = that.importPath,
                ip.stopIndex.intValue() 
                        <= endOfCodeInLine) {
                
                change.addEdit(InsertEdit {
                    start = ip.endIndex.intValue();
                    text = " { ... }";
                });
            }
            
            super.visit(that);
        }

        overloaded
        shared actual void visit(Tree.ImportModule that) {
            super.visit(that);
            if (that.importPath exists 
             || that.quotedLiteral exists) {
                terminate(that, CL.semicolon, ";");
            }
            
            if (!that.version exists,
                !change.hasEdits,
                exists ip = that.importPath,
                ip.stopIndex.intValue() 
                        <= endOfCodeInLine) {
                
                change.addEdit(InsertEdit {
                    start = ip.endIndex.intValue();
                    text = " \"1.0.0\"";
                });
            }
        }

        overloaded
        shared actual void visit(Tree.ImportModuleList that) {
            super.visit(that);
            terminate(that, CL.rbrace, " }");
        }

        overloaded
        shared actual void visit(Tree.PackageDescriptor that) {
            super.visit(that);
            terminate(that, CL.semicolon, ";");
        }

        overloaded
        shared actual void visit(Tree.Directive that) {
            super.visit(that);
            terminate(that, CL.semicolon, ";");
        }

        overloaded
        shared actual void visit(Tree.Body that) {
            super.visit(that);
            terminate(that, CL.rbrace, " }");
        }

        overloaded
        shared actual void visit(Tree.MetaLiteral that) {
            super.visit(that);
            terminate(that, CL.backtick, "`");
        }

        overloaded
        shared actual void visit(Tree.StatementOrArgument that) {
            super.visit(that);
            if (is Tree.SpecifiedArgument that) {
                terminate(that, CL.semicolon, ";");
            }
        }
        
        Boolean inLine(Node that) 
                => if (exists start = that.startIndex) 
                then start.intValue() >= startOfCodeInLine
                  && start.intValue() <= endOfCodeInLine
                else false;
        
        void terminate(Node that, Integer tokenType, String ch) {
            if (inLine(that)) {
                Token? et = that.mainEndToken;
                if ((et?.type else -1) != tokenType
                    || that.stopIndex.intValue() 
                            > endOfCodeInLine, 
                    !change.hasEdits) {
                    
                    change.addEdit(InsertEdit {
                        start = smallest(endOfCodeInLine, 
                                    that.stopIndex.intValue())
                                + 1;
                        text = ch;
                    });
                }
            }
        }

        overloaded
        shared actual void visit(Tree.ClassDeclaration that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit {
                    start = that.identifier.endIndex.intValue();
                    text = "()";
                });
            }
        }

        overloaded
        shared actual void visit(Tree.ClassDefinition that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                that.classBody exists,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit {
                    start = that.identifier.endIndex.intValue();
                    text = "()";
                });
            }
        }

        overloaded
        shared actual void visit(Tree.Constructor that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                that.block exists,
                !change.hasEdits) {
                assert (is CommonToken tok 
                    = if (exists id = that.identifier)
                    then id.token 
                    else that.mainToken);
                
                change.addEdit(InsertEdit {
                    start = tok.stopIndex + 1;
                    text = "()";
                });
            }
        }

        overloaded
        shared actual void visit(Tree.AnyMethod that) {
            super.visit(that);
            if (inLine(that),
                that.parameterLists.empty,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit {
                    start = that.identifier.endIndex.intValue();
                    text = "()";
                });
            }
        }
    }

    Boolean skipToken(List<CommonToken> tokens, Integer offset) {
        value ti = nodes.getTokenIndexAtCharacter(tokens, offset);
        value type = tokens.get(ti<0 then -ti else ti).type;
        return type==CL.ws
            || type==CL.multiComment
            || type==CL.lineComment;
    }

}
