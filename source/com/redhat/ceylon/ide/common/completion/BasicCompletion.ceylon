import ceylon.collection {
    MutableList
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Scope
}

shared interface BasicCompletion<IdeComponent,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document> {
    
    shared formal CompletionResult newBasicCompletionProposal(Integer offset,
        String prefix, String text, String escapedText, Declaration decl,
        IdeComponent cmp);
    
    shared void addImportProposal(Integer offset, String prefix,
        IdeComponent cpc, MutableList<CompletionResult> result,
        Declaration dec, Scope scope) {
        
        result.add(newBasicCompletionProposal(offset, prefix, dec.name,
            escaping.escapeName(dec), dec, cpc));
    }
    
    shared void addDocLinkProposal(Integer offset, String prefix,
        IdeComponent cpc, MutableList<CompletionResult> result,
        Declaration dec, Scope scope) {
        
        //for doc links, propose both aliases and unaliased qualified form
        //we don't need to do this in code b/c there is no fully-qualified form
        String name = dec.name;
        value cu = cpc.lastCompilationUnit;
        String aliasedName = dec.getName(cu.unit);
        if (!name.equals(aliasedName)) {
            result.add(newBasicCompletionProposal(offset, prefix, aliasedName,
                aliasedName, dec, cpc));
        }
        result.add(newBasicCompletionProposal(offset, prefix, name, 
            getTextForDocLink(cu.unit, dec), dec, cpc));
    }
}
