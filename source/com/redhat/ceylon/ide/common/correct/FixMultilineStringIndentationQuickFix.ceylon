import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

import java.lang {
    JString=String
}

shared interface FixMultilineStringIndentationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change);
    
    shared void addFixMultilineStringIndentation(Data data, IFile file) {
        if (is Tree.StringLiteral literal = data.node) {
            value change = newTextChange("Fix Multiline String", file);
            value doc = getDocumentForChange(change);
            value offset = literal.startIndex.intValue();
            value length = literal.distance.intValue();
            value token = literal.token;
            value indentation = token.charPositionInLine + getStartQuoteLength(token.type);

            if (exists text = getFixedText(token.text, indentation, doc)) {
                addEditToChange(change, newReplaceEdit(offset, length, text));
                newProposal(data, "Fix multiline string indentation", change);
            }
        }
    }
    
    String? getFixedText(String text, Integer indentation, IDocument doc) {
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
            
            result.append(indents.getDefaultLineDelimiter(doc));
        }
        
        result.deleteTerminal(1);
        
        return result.string;
    }
    
    Integer getStartQuoteLength(Integer type) {
        Integer startQuoteLength;
        
        if (type in [CeylonLexer.\iSTRING_LITERAL, CeylonLexer.\iASTRING_LITERAL, CeylonLexer.\iSTRING_START]) {
            startQuoteLength = 1;
        } else if (type in [CeylonLexer.\iSTRING_MID, CeylonLexer.\iSTRING_END]) {
            startQuoteLength = 2;
        } else if (type in [CeylonLexer.\iVERBATIM_STRING, CeylonLexer.\iAVERBATIM_STRING]) {
            startQuoteLength = 3;
        } else {
            startQuoteLength = -1;
        }
        
        return startQuoteLength;
    }
}
