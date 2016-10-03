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
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            description = dec.name;
            text = escaping.escapeName(dec);
            icon = dec;
        };
    }
    
    shared void addDocLinkProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        //for doc links, propose both aliases and unaliased qualified form
        //we don't need to do this in code b/c there is no fully-qualified form
        String name = dec.name;
        value unit = ctx.lastCompilationUnit.unit;
        String aliasedName = dec.getName(unit);

        if (name!=aliasedName) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                description = aliasedName;
                icon = dec;
            };
        }
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            description = name;
            text = getTextForDocLink(unit, dec);
            icon = dec;
        };
    }
}
