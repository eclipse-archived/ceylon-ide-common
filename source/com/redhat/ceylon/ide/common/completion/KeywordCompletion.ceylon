import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    escaping
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

// see KeywordCompletionProposal
shared interface KeywordCompletion {
    
    value postfixKeywords => [
        "of", "in", "else", "exists", "nonempty", "then"
    ];
    
    value expressionKeywords => [
        "object", "value", "void", "function",
        "this", "outer", "super",
        "of", "in", "else", "for", "if", "is",
        "exists", "nonempty", "then", "let"
    ];
    
    value conditionKeywords => [
        "assert", "let", "while", "for", "if", "switch", "case", "catch"
    ];
    
    // see KeywordCompletionProposal.addKeywordProposals(...)
    shared void addKeywordProposals(CompletionContext ctx, Tree.CompilationUnit cu,
        Integer offset, String prefix, Node node, OccurrenceLocation? ol,
        Boolean postfix, Integer previousTokenType) {
        
        if (isModuleDescriptor(cu),
            !isLocation(ol, OccurrenceLocation.meta),
            !(ol?.reference else false)) {
            //outside of backtick quotes, the only keyword allowed
            //in a module descriptor is "import"
            if ("import".startsWith(prefix)) {
                addKeywordProposal(ctx, offset, prefix, "import");
            }
        } else if (!prefix.empty,
            !isLocation(ol, OccurrenceLocation.\icatch),
            !isLocation(ol, OccurrenceLocation.\icase)) {
            
            //TODO: this filters out satisfies/extends in an object named arg
            value keywords = 
                    if (isLocation(ol, OccurrenceLocation.expression))
                    then (postfix then postfixKeywords else expressionKeywords)
                    else escaping.keywords;
            
            keywords.filter((kw) => kw.startsWith(prefix)).each(
                (kw) => addKeywordProposal(ctx, offset, prefix, kw)
            );
        } else if (isLocation(ol, OccurrenceLocation.\icase),
            previousTokenType == CeylonLexer.lparen) {
            
            addKeywordProposal(ctx, offset, prefix, "is");
        } else if (!prefix.empty,
            isLocation(ol, OccurrenceLocation.\icase)) {
            
            if ("case".startsWith(prefix)) {
                addKeywordProposal(ctx, offset, prefix, "case");
            }
        } else if (!exists ol,
            is Tree.ConditionList node,
            previousTokenType == CeylonLexer.lparen) {
            
            addKeywordProposal(ctx, offset, prefix, "exists");
            addKeywordProposal(ctx, offset, prefix, "nonempty");
        } else if (isLocation(ol, OccurrenceLocation.\iextends)) {
            addKeywordProposal(ctx, offset, prefix, "package");
            addKeywordProposal(ctx, offset, prefix, "super");
        }
    }
    
    void addKeywordProposal(CompletionContext ctx, Integer offset,
        String prefix, String kw) {
        
        value text = kw in conditionKeywords then "``kw`` ()" else kw;
        value selection = if (exists close = text.firstOccurrence(')'))
        then DefaultRegion(offset + close - prefix.size, 0)
        else null;
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            description = kw;
            text = text;
            icon = Icons.ceylonLiteral;
            selection = selection;
            kind = keyword;
        };
    }
}
