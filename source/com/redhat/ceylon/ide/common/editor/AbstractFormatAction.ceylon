import ceylon.collection {
    ArrayList
}
import ceylon.file {
    Writer
}
import ceylon.formatter {
    invokeFormatter=format
}
import ceylon.formatter.options {
    SparseFormattingOptions,
    combinedOptions,
    FormattingOptions
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    TextChange,
    CommonDocument,
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

import java.lang {
    IllegalStateException
}
import java.util {
    List
}

import org.antlr.runtime {
    CommonToken,
    TokenSource,
    Token,
    BufferedTokenStream
}

shared object formatAction {
    
    // TODO this could be a tuple I guess
    class FormattingUnit(shared Node node, shared CommonToken startToken, shared CommonToken endToken) {
    }
    
    shared TextChange? format(Tree.CompilationUnit rootNode, List<CommonToken> tokenList,
        CommonDocument document, Integer docLength, DefaultRegion selection,
        SparseFormattingOptions options, FormattingOptions formatterProfile) {
        
        value formattingUnits = ArrayList<FormattingUnit>();
        value formatAll = selection.length==0 || selection.length==docLength;
        
        if (!formatAll) {
            // a node was selected, format only that
            value selectedRootNode = nodes.findNode(rootNode, tokenList, selection.start,
                selection.start + selection.length);
            
            if (!exists selectedRootNode) {
                return null;
            }
            
            assert (is CommonToken startToken = selectedRootNode.token);
            assert (is CommonToken endToken = selectedRootNode.endToken);
            
            if (is Tree.Body|Tree.CompilationUnit selectedRootNode) {
                // format only selected statements, not entire body / CU (from now on: body)
                value it = if (is Tree.Body selectedRootNode)
                then selectedRootNode.statements.iterator()
                else selectedRootNode.declarations.iterator();
                
                variable value tokenIndex = -1;
                // find first selected statement
                while (it.hasNext()) {
                    value stat = it.next();
                    assert (is CommonToken start = stat.token);
                    assert (is CommonToken end = stat.endToken);
                    if (end.stopIndex >= selection.start) {
                        formattingUnits.add(FormattingUnit(stat, start, end));
                        tokenIndex = end.tokenIndex + 1;
                        break;
                    }
                }
                
                // find last selected statement
                while (it.hasNext()) {
                    value stat = it.next();
                    assert (is CommonToken start = stat.token);
                    assert (is CommonToken end = stat.endToken);
                    if (start.startIndex >= selection.start+selection.length) {
                        break;
                    }
                    
                    formattingUnits.add(FormattingUnit(stat, tokenList.get(tokenIndex), end));
                    tokenIndex = end.tokenIndex + 1;
                }
                
                if (formattingUnits.empty) {
                    // possible if the selection spanned the entire content of the body,
                    // or if the body is empty, etc.
                    formattingUnits.add(FormattingUnit(selectedRootNode, startToken, endToken));
                }
            } else {
                formattingUnits.add(FormattingUnit(selectedRootNode, startToken, endToken));
            }
        } else {
            // format everything
            formattingUnits.add(FormattingUnit(rootNode, tokenList.get(0), tokenList.get(tokenList.size() - 1)));
        }
        
        value builder = StringBuilder();
        
        assert (exists firstUnit = formattingUnits.get(0));
        
        for (unit in formattingUnits) {
            value startTokenIndex = unit.startToken.tokenIndex;
            value endTokenIndex = unit.endToken.tokenIndex;
            value tokens = object satisfies TokenSource {
                variable value i = startTokenIndex;
                shared actual Token? nextToken() {
                    if (i <= endTokenIndex) {
                        return tokenList.get(i++);
                    } else if (i == endTokenIndex+1) {
                        return tokenList.get(tokenList.size() - 1); // EOF token
                    } else {
                        return null;
                    }
                }
                
                shared actual String sourceName {
                    throw IllegalStateException("No one should need this");
                }
            };
            
            if (exists indentMode = options.indentMode) {
                value indentLevel = document.getIndent(unit.node)
                    .replace("\t", indentMode.indent(1)).size
                        / document.indentSpaces;
                
                if (unit != firstUnit) {
                    // add indentation
                    builder.append(indentMode.indent(indentLevel));
                }

                value writer = object satisfies Writer {
                    shared actual void close() {}
                    
                    shared actual void flush() {}
                    
                    shared actual void write(String string) {
                        builder.append(string);
                    }
                    
                    shared actual void writeBytes({Byte*} bytes) {
                    }
                    
                    shared actual void writeLine(String line) {
                        builder.append(string);
                    }
                };
                invokeFormatter(unit.node, combinedOptions(formatterProfile, options),
                    writer, BufferedTokenStream(tokens), indentLevel);
            }
            
            
            if (unit == firstUnit) {
                // trim leading indentation (from formatter's indentBefore)
                variable value firstNonWsIndex = 0;
                while (builder[firstNonWsIndex]?.whitespace else false) {
                    firstNonWsIndex++;
                }
                
                if (firstNonWsIndex != 0) {
                    builder.deleteInitial(firstNonWsIndex);
                }
            }
        }
        
        String text;
        if (selection.length > 0) {
            // remove the trailing line break
            assert(exists lb = options.lineBreak);
            text = builder.string.spanTo(builder.size - lb.text.size - 1);
        } else {
            text = builder.string;
        }
        
        value startIndex = firstUnit.startToken.startIndex;
        assert(exists lastUnit = formattingUnits.get(formattingUnits.size - 1));
        value stopIndex = lastUnit.endToken.stopIndex;
        value from = if (formatAll) then 0 else startIndex;
        value length = if (formatAll) then docLength else stopIndex - startIndex + 1;
        
        //if (!document.get(from, length).equals(text)) {
        value change = platformServices.createTextChange("Format", document);
        change.addEdit(ReplaceEdit(from, length, text));
        
        return change;
        //}
        
        //return null;
    }
}
