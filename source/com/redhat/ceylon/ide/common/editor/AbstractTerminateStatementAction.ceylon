import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
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

shared interface AbstractTerminateStatementAction<Document=DefaultDocument>
        given Document satisfies CommonDocument {
    
    shared formal [Tree.CompilationUnit, List<CommonToken>] parse(Document doc);

    shared void terminateStatement(Document doc, Integer line) {
        terminateWithSemicolon(doc, line);
        variable Boolean changed = true;
        variable Integer count = 0;
        
        while (changed && count < 5) {
            changed = terminateWithBrace(doc, line);
            count++;
        }
    }
    
    Boolean terminateWithBrace(Document doc, Integer line) {
        value change = platformServices.createTextChange("Terminate Statement", doc);
        change.initMultiEdit();
        value [rootNode, tokens] = parse(doc);
        value lineRegion = doc.getLineRegion(line);
        value lineText = doc.getLineContent(line);
        value startOfCodeInLine = getCodeStart(lineRegion, lineText, tokens);
        value endOfCodeInLine = getCodeEnd(lineRegion, lineText, tokens);
        
        TerminateWithBraceProcessor(startOfCodeInLine,
            endOfCodeInLine, change).visit(rootNode);
            
        if (change.hasEdits) {
            change.apply();
            return true;
        }
        return false;
    }

    Boolean terminateWithSemicolon(Document doc, Integer line) {
        value change = platformServices.createTextChange("Terminate Statement", doc);
        change.initMultiEdit();
        value [rootNode, tokens] = parse(doc);
        value lineRegion = doc.getLineRegion(line);
        value lineText = doc.getLineContent(line);
        value endOfCodeInLine = getCodeEnd(lineRegion, lineText, tokens);

        if (doc.getChar(endOfCodeInLine) != ';') {
            TerminateWithSemicolonProcessor(
                endOfCodeInLine, change).visit(rootNode);
            
            if (change.hasEdits) {
                change.apply();
                return true;
            }
        }

        return false;
    }

    Integer getCodeEnd(DefaultRegion li, String lineText, List<CommonToken> tokens) {
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
    
    Integer getCodeStart(DefaultRegion li, String lineText, List<CommonToken> tokens) {
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
        shared actual void visit(Tree.Annotation that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }
        
        shared actual void visit(Tree.StaticType that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }
        
        shared actual void visit(Tree.Expression that) {
            super.visit(that);
            terminateWithSemicolon(that);
        }
        
        Boolean terminatedInLine(Node? node) {
            return if (exists node, node.startIndex.intValue() <= endOfCodeInLine)
                    then true else false;
        }
        
        shared actual void visit(Tree.IfClause that) {
            super.visit(that);
            if (missingBlock(that.block), terminatedInLine(that.conditionList)) {
                terminateWithParenAndBaces(that, that.conditionList);
            }
        }
        
        shared actual void visit(Tree.ElseClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBaces(that);
            }
        }
        
        shared actual void visit(Tree.ForClause that) {
            super.visit(that);
            if (missingBlock(that.block), terminatedInLine(that.forIterator)) {
                terminateWithParenAndBaces(that, that.forIterator);
            }
        }
        
        shared actual void visit(Tree.WhileClause that) {
            super.visit(that);
            if (missingBlock(that.block), terminatedInLine(that.conditionList)) {
                terminateWithParenAndBaces(that, that.conditionList);
            }
        }
        
        shared actual void visit(Tree.CaseClause that) {
            super.visit(that);
            if (missingBlock(that.block), terminatedInLine(that.caseItem)) {
                terminateWithParenAndBaces(that, that.caseItem);
            }
        }
        
        shared actual void visit(Tree.TryClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBaces(that);
            }
        }
        
        shared actual void visit(Tree.CatchClause that) {
            super.visit(that);
            if (missingBlock(that.block), terminatedInLine(that.catchVariable)) {
                terminateWithParenAndBaces(that, that.catchVariable);
            }
        }
        
        shared actual void visit(Tree.FinallyClause that) {
            super.visit(that);
            if (missingBlock(that.block)) {
                terminateWithBaces(that);
            }
        }
        
        shared actual void visit(Tree.StatementOrArgument that) {
            if (that is Tree.ExecutableStatement && !(that is Tree.ControlStatement) || that is Tree.AttributeDeclaration || that is Tree.ImportModule || that is Tree.TypeAliasDeclaration || that is Tree.SpecifiedArgument) {
                terminateWithSemicolon(that);
            }
            
            if (is Tree.MethodDeclaration that) {
                value md = that;
                if (!md.specifierExpression exists) {
                    value pl = md.parameterLists;
                    if (md.identifier exists, terminatedInLine(md.identifier)) {
                        terminateWithParenAndBaces(that,
                            if (pl.empty) then null else pl.get(pl.size() - 1));
                    }
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            if (is Tree.ClassDeclaration that) {
                value cd = that;
                if (!cd.classSpecifier exists) {
                    terminateWithParenAndBaces(that, cd.parameterList);
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            if (is Tree.InterfaceDeclaration that) {
                value id = that;
                if (!id.typeSpecifier exists) {
                    terminateWithBaces(that);
                } else {
                    terminateWithSemicolon(that);
                }
            }
            
            super.visit(that);
        }
        
        void terminateWithParenAndBaces(Node that, Node? subnode) {
            try {
                if (withinLine(that)) {
                    value startIndex = subnode?.startIndex?.intValue()
                            else endOfCodeInLine + 1;
                    if (startIndex > endOfCodeInLine) {
                        if (!change.hasEdits) {
                            change.addEdit(
                                InsertEdit(endOfCodeInLine + 1, "() {}"));
                        }
                    } else {
                        assert(exists subnode);
                        Token? et = that.endToken;
                        Token? set = subnode.endToken;
                        if (!set exists
                            || (set?.type else 0) !=CeylonLexer.\iRPAREN
                            || subnode.stopIndex.intValue() > endOfCodeInLine) {
                            
                            if (!change.hasEdits) {
                                value edit = InsertEdit(endOfCodeInLine + 1, ") {}");
                                change.addEdit(edit);
                            }
                        } else if (!et exists
                            || (et?.type else 0)!=CeylonLexer.\iRBRACE
                            || that.stopIndex.intValue() > endOfCodeInLine) {
                            
                            if (!change.hasEdits) {
                                value edit = InsertEdit(endOfCodeInLine + 1, " {}");
                                change.addEdit(edit);
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        void terminateWithBaces(Node that) {
            try {
                if (withinLine(that)) {
                    Token? et = that.endToken;
                    if (!et exists
                        || (et?.type else 0) !=CeylonLexer.\iSEMICOLON
                        && (et?.type else 0) !=CeylonLexer.\iRBRACE
                        || that.stopIndex.intValue() > endOfCodeInLine) {
                        
                        if (!change.hasEdits) {
                            value edit = InsertEdit(endOfCodeInLine + 1, " {}");
                            change.addEdit(edit);
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        void terminateWithSemicolon(Node that) {
            try {
                if (withinLine(that)) {
                    Token? et = that.endToken;
                    if (!et exists
                        || (et?.type else 0) !=CeylonLexer.\iSEMICOLON
                        || that.stopIndex.intValue() > endOfCodeInLine) {
                        
                        if (!change.hasEdits) {
                            value edit = InsertEdit(endOfCodeInLine + 1, ";");
                            change.addEdit(edit);
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        Boolean withinLine(Node that) 
                => if (exists start = that.startIndex,
                       exists stop = that.stopIndex)
                then start.intValue() <= endOfCodeInLine
                    && stop.intValue() >= endOfCodeInLine
                else false;
        
        Boolean missingBlock(Tree.Block? block) {
            return !block exists 
                    || !block?.mainToken exists 
                    || (block?.mainToken?.text?.startsWith("<missing")
                    else true);
        }
    }


    class TerminateWithBraceProcessor(
        Integer startOfCodeInLine,
        Integer endOfCodeInLine,
        TextChange change
    ) extends Visitor() {
        
        shared actual void visit(Tree.Expression that) {
            super.visit(that);
            if (exists start = that.startIndex, 
                exists stop = that.stopIndex,
                stop.intValue() <= endOfCodeInLine &&
                start.intValue() >= startOfCodeInLine,
                exists st = that.mainToken,
                st.type == CeylonLexer.\iLPAREN,
                ((that.mainEndToken?.type else -1) !=CeylonLexer.\iRPAREN),
                !change.hasEdits) {

                value edit = InsertEdit(that.endIndex.intValue(), ")");
                change.addEdit(edit);
            }
        }
        
        shared actual void visit(Tree.ParameterList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRPAREN, ")");
        }
        
        shared actual void visit(Tree.IndexExpression that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACKET, "]");
        }
        
        shared actual void visit(Tree.TypeParameterList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iLARGER_OP, ">");
        }
        
        shared actual void visit(Tree.TypeArgumentList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iLARGER_OP, ">");
        }
        
        shared actual void visit(Tree.PositionalArgumentList that) {
            super.visit(that);
            if (exists t = that.token,
                t.type == CeylonLexer.\iLPAREN) {
                
                terminate(that, CeylonLexer.\iRPAREN, ")");
            }
        }
        
        shared actual void visit(Tree.NamedArgumentList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, " }");
        }
        
        shared actual void visit(Tree.SequenceEnumeration that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, " }");
        }
        
        shared actual void visit(Tree.IterableType that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, "}");
        }
        
        shared actual void visit(Tree.Tuple that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACKET, "]");
        }
        
        shared actual void visit(Tree.TupleType that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACKET, "]");
        }
        
        shared actual void visit(Tree.ConditionList that) {
            super.visit(that);
            if (!that.mainToken.text.startsWith("<missing ")) {
                terminate(that, CeylonLexer.\iRPAREN, ")");
            }
        }
        
        shared actual void visit(Tree.ForIterator that) {
            super.visit(that);
            if (!that.mainToken.text.startsWith("<missing ")) {
                terminate(that, CeylonLexer.\iRPAREN, ")");
            }
        }
        
        shared actual void visit(Tree.ImportMemberOrTypeList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, " }");
        }
        
        shared actual void visit(Tree.Import that) {
            if (!that.importMemberOrTypeList exists || that.importMemberOrTypeList.mainToken.text.startsWith("<missing ")) {
                if (!change.hasEdits,
                    exists ip = that.importPath,
                    ip.stopIndex.intValue() <= endOfCodeInLine) {
                        
                    value edit = InsertEdit(ip.endIndex.intValue(), " { ... }");
                    change.addEdit(edit);
                }
            }
            
            super.visit(that);
        }
        
        shared actual void visit(Tree.ImportModule that) {
            super.visit(that);
            if (that.importPath exists || that.quotedLiteral exists) {
                terminate(that, CeylonLexer.\iSEMICOLON, ";");
            }
            
            if (!that.version exists,
                !change.hasEdits,
                exists ip = that.importPath,
                ip.stopIndex.intValue() <= endOfCodeInLine) {
                    
                value edit = InsertEdit(ip.endIndex.intValue(), " \"1.0.0\"");
                change.addEdit(edit);
            }
        }
        
        shared actual void visit(Tree.ImportModuleList that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, " }");
        }
        
        shared actual void visit(Tree.PackageDescriptor that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iSEMICOLON, ";");
        }
        
        shared actual void visit(Tree.Directive that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iSEMICOLON, ";");
        }
        
        shared actual void visit(Tree.Body that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iRBRACE, " }");
        }
        
        shared actual void visit(Tree.MetaLiteral that) {
            super.visit(that);
            terminate(that, CeylonLexer.\iBACKTICK, "`");
        }
        
        shared actual void visit(Tree.StatementOrArgument that) {
            super.visit(that);
            if (is Tree.SpecifiedArgument that) {
                terminate(that, CeylonLexer.\iSEMICOLON, ";");
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
                    || that.stopIndex.intValue() > endOfCodeInLine) {
                    
                    if (!change.hasEdits) {
                        value edit = InsertEdit(
                            min({endOfCodeInLine, that.stopIndex.intValue()}) + 1,
                            ch);
                        change.addEdit(edit);
                    }
                }
            }
        }
        
        shared actual void visit(Tree.ClassDeclaration that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                !change.hasEdits) {

                change.addEdit(InsertEdit(that.identifier.endIndex.intValue(), "()"));
            }
        }
        
        shared actual void visit(Tree.ClassDefinition that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                that.classBody exists,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit(that.identifier.endIndex.intValue(), "()"));
            }
        }
        
        shared actual void visit(Tree.Constructor that) {
            super.visit(that);
            if (inLine(that),
                !that.parameterList exists,
                that.block exists,
                !change.hasEdits) {

                Tree.Identifier? id = that.identifier;
                assert (is CommonToken tok = (if (!exists id)
                    then that.mainToken else id.token));
                
                change.addEdit(InsertEdit(tok.stopIndex + 1, "()"));
            }
        }
        
        shared actual void visit(Tree.AnyMethod that) {
            super.visit(that);
            if (inLine(that),
                that.parameterLists.empty,
                !change.hasEdits) {
                
                change.addEdit(InsertEdit(that.identifier.endIndex.intValue(), "()"));
            }
        }
    }

    Boolean skipToken(List<CommonToken> tokens, Integer offset) {
        variable value ti = nodes.getTokenIndexAtCharacter(tokens, offset);
        if (ti < 0) {
            ti = -ti;
        }
        
        value type = tokens.get(ti).type;
        return type==CeylonLexer.\iWS
                || type==CeylonLexer.\iMULTI_COMMENT
                || type==CeylonLexer.\iLINE_COMMENT;
    }

}

