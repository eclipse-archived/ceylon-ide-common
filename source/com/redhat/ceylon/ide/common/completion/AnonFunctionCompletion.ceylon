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

        value header = anonFunctionHeader {
            requiredType = requiredType;
            unit = unit;
            param = parameter;
        };
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            description = header + " => nothing";
            prefix = "";
            icon = Icons.correction;
            selection = DefaultRegion {
                start = offset + header.size + 4;
                length = 7;
            };
        };
        
        if (exists parameter, parameter.declaredVoid) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                description = header + " {}";
                prefix = "";
                icon = Icons.correction;
                selection = DefaultRegion {
                    start = offset + header.size + 2;
                    length = 0;
                };
            };
        }
    }
}
