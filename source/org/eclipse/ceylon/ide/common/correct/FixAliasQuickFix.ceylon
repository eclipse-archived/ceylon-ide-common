import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
shared object fixAliasQuickFix {
    
    shared void addFixAliasProposal(QuickFixData data) {
        value offset = data.problemOffset;
        value change 
                = platformServices.document.createTextChange {
            name = "Fix Alias Syntax";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        change.addEdit(ReplaceEdit(offset, 1, "=>"));
        
        data.addQuickFix {
            description = "Change = to =>";
            change = change;
            selection = DefaultRegion(offset + 2);
        };
    }
}
