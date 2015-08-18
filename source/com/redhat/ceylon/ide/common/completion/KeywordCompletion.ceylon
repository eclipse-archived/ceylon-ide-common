import ceylon.collection {
    HashSet,
    linked,
    Hashtable,
    MutableList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    escaping
}

// see KeywordCompletionProposal
shared interface KeywordCompletion<CompletionComponent> {
    
    Set<String> postfixKeywords => HashSet(linked, Hashtable(), {"of", "in", "else", "exists", "nonempty", "then"});

    Set<String> expressionKeywords => HashSet(linked, Hashtable(), {"object", "value", "void", "function", 
                    "this", "outer", "super", 
                    "of", "in", "else", "for", "if", "is", 
                    "exists", "nonempty", "then", "let"});
    
    shared formal CompletionComponent newKeywordCompletionProposal(Integer offset, String prefix, String keyword);
    
    // see KeywordCompletionProposal.addKeywordProposals(...)
    shared void addKeywordProposals(Tree.CompilationUnit cu, Integer offset, String prefix, MutableList<CompletionComponent> result,
            Node node, OccurrenceLocation? ol, Boolean postfix, Integer previousTokenType) {
        
        if (isModuleDescriptor(cu), !isLocation(ol, OccurrenceLocation.\iMETA), !(ol?.reference else false)){
            //outside of backtick quotes, the only keyword allowed
            //in a module descriptor is "import"
            if ("import".startsWith(prefix)) {
                addKeywordProposal(offset, prefix, result, "import");
            }
        } else if (!prefix.empty, !isLocation(ol, OccurrenceLocation.\iCATCH), !isLocation(ol, OccurrenceLocation.\iCASE)) {
            //TODO: this filters out satisfies/extends in an object named arg
            value keywords = if (isLocation(ol, OccurrenceLocation.\iEXPRESSION))
                             then if (postfix) then postfixKeywords else expressionKeywords
                             else CeylonIterable(escaping.keywords);

            for (keyword in keywords) {
                value str = if (is String keyword) then keyword else keyword.string;
                if (str.startsWith(prefix)) {
                    addKeywordProposal(offset, prefix, result, str);
                }
            }
        } else if (isLocation(ol, OccurrenceLocation.\iCASE), previousTokenType == CeylonLexer.\iLPAREN) {
            addKeywordProposal(offset, prefix, result, "is");
        } else if (!prefix.empty, isLocation(ol, OccurrenceLocation.\iCASE)) {
            if ("case".startsWith (prefix)) {
                addKeywordProposal (offset, prefix, result, "case");
            }
        } else if (!exists ol, is Tree.ConditionList node, previousTokenType == CeylonLexer.\iLPAREN) {
            addKeywordProposal (offset, prefix, result, "exists");
            addKeywordProposal (offset, prefix, result, "nonempty");
        } else if (isLocation(ol, OccurrenceLocation.\iEXTENDS)) {
            addKeywordProposal (offset, prefix, result, "package");
            addKeywordProposal (offset, prefix, result, "super");
        }
    }
    
    void addKeywordProposal(Integer offset, String prefix, MutableList<CompletionComponent> result, String keyword)
        => result.add(newKeywordCompletionProposal(offset, prefix, keyword));
}