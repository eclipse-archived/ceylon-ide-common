import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    CommonDocument,
    ReplaceEdit
}

import java.lang {
    JString=String
}

shared object fixMultilineStringIndentationQuickFix {
    
    shared void addFixMultilineStringIndentation(QuickFixData data) {
        if (is Tree.StringLiteral literal = data.node) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Fix Multiline String";
                input = data.phasedUnit;
            };
            value doc = change.document;
            value offset = literal.startIndex.intValue();
            value length = literal.distance.intValue();
            value token = literal.token;
            if (exists text = getFixedText {
                text = token.text;
                indentation 
                        = token.charPositionInLine 
                        + getStartQuoteLength(token.type);
                doc = doc;
            }) {
                change.addEdit(ReplaceEdit {
                    start = offset;
                    length = length;
                    text = text;
                });
                data.addQuickFix {
                    description = "Fix multiline string indentation";
                    change = change;
                };
            }
        }
    }
    
    String? getFixedText(String text, Integer indentation, CommonDocument doc) {
        value result = StringBuilder();
        value parts = JString(text).split("\n|\r\n?");
        
        for (idx in 0..parts.size - 1) {
            variable value line = parts.get(idx).string;
            
            if (result.size == 0) {
                result.append(line);
            } else {
                variable value i = 0;
                while (i < indentation) {
                    result.append(" ");
                    if (line.startsWith(" ")) {
                        line = line.spanFrom(1);
                    }
                    
                    i++;
                }
                
                result.append(line);
            }
            
            result.append(doc.defaultLineDelimiter);
        }
        
        result.deleteTerminal(1);
        
        return result.string;
    }
    
    Integer getStartQuoteLength(Integer type) {
        Integer startQuoteLength;
        
        if (type in [CeylonLexer.stringLiteral, CeylonLexer.astringLiteral, CeylonLexer.stringStart]) {
            startQuoteLength = 1;
        } else if (type in [CeylonLexer.stringMid, CeylonLexer.stringEnd]) {
            startQuoteLength = 2;
        } else if (type in [CeylonLexer.verbatimString, CeylonLexer.averbatimString]) {
            startQuoteLength = 3;
        } else {
            startQuoteLength = -1;
        }
        
        return startQuoteLength;
    }
}
