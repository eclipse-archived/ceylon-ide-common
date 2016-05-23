import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.ide.common.util {
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Scope
}

shared interface BasicCompletion {
    
    shared void addImportProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        platformServices.completion.newBasicCompletionProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            text = dec.name;
            escapedText = escaping.escapeName(dec);
            decl = dec;
        };
    }
    
    shared void addDocLinkProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        //for doc links, propose both aliases and unaliased qualified form
        //we don't need to do this in code b/c there is no fully-qualified form
        String name = dec.name;
        value cu = ctx.lastCompilationUnit;
        String aliasedName = dec.getName(cu.unit);

        if (!name.equals(aliasedName)) {
            platformServices.completion.newBasicCompletionProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                text = aliasedName;
                escapedText = aliasedName;
                decl = dec;
            };
        }
        
        platformServices.completion.newBasicCompletionProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            text = name;
            escapedText = getTextForDocLink(cu.unit, dec);
            decl = dec;
        };
    }
}
