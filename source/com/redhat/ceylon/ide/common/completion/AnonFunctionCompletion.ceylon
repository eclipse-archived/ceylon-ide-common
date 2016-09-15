import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    Parameter
}

shared interface AnonFunctionCompletion {

    shared void addAnonFunctionProposal(CompletionContext ctx, Integer offset,
        Type? requiredType, Parameter? parameter, Unit unit) {

        value text = anonFunctionHeader {
            requiredType = requiredType;
            unit = unit;
            param = parameter;
        };
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            description = text + " => nothing";
            prefix = "";
            icon = Icons.correction;
            selection = DefaultRegion {
                start = offset + text.size + 4;
                length = 7;
            };
        };
        
        if (unit.getCallableReturnType(requiredType).anything) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                description = "void ``text`` {}";
                prefix = "";
                icon = Icons.correction;
                selection = DefaultRegion {
                    start = offset + text.size + 7;
                    length = 0;
                };
            };
        }
    }
}
