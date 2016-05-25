import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared interface AnonFunctionCompletion {
    
    shared void addAnonFunctionProposal(CompletionContext ctx, Integer offset,
        Type? requiredType, Unit unit) {
        
        value text = anonFunctionHeader(requiredType, unit);
        value funtext = text + " => nothing";
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            description = funtext;
            prefix = "";
            icon = Icons.correction;
            selection = DefaultRegion(
                offset + (funtext.firstInclusion("nothing") else 0),
                7
            );
        };
        
        if (unit.getCallableReturnType(requiredType).anything) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                description = "void " + text + " {}";
                prefix = "";
                selection = DefaultRegion(offset + funtext.size - 1, 0);
                icon = Icons.correction;
            };
        }
    }
}
