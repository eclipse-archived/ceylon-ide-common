import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type
}

shared interface AnonFunctionCompletion {
    
    shared void addAnonFunctionProposal(CompletionContext ctx, Integer offset,
        Type? requiredType, Unit unit) {
        
        value text = anonFunctionHeader(requiredType, unit);
        value funtext = text + " => nothing";
        
        platformServices.completion.newAnonFunctionProposal {
            ctx = ctx;
            offset = offset;
            requiredType = requiredType;
            unit = unit;
            text = funtext;
            header = text;
            isVoid = false;
            selectionStart = offset + (funtext.firstInclusion("nothing") else 0);
            selectionLength = 7;
        };
        
        if (unit.getCallableReturnType(requiredType).anything) {
            platformServices.completion.newAnonFunctionProposal {
                ctx = ctx;
                offset = offset;
                requiredType = requiredType;
                unit = unit;
                text = "void " + text + " {}";
                header = text;
                isVoid = true;
                selectionStart = offset + funtext.size - 1;
                selectionLength = 0;
            };
        }
    }
}
