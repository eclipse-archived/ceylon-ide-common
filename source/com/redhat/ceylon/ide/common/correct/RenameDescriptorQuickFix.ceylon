import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.util {
    escaping
}

shared object renameDescriptorQuickFix {
    
    shared void addRenameDescriptorProposal(QuickFixData data) {
        value pack = data.rootNode.unit.\ipackage;
        value pname = escaping.escapePackageName(pack);
        
        value change 
                = platformServices.createTextChange {
            name = "Rename";
            input = data.phasedUnit;
        };
        
        change.addEdit(ReplaceEdit {
            start = data.problemOffset;
            length = data.problemLength;
            text = pname;
        });
        
        data.addQuickFix {
            description = "Rename to '``pack.qualifiedNameString``'";
            change = change;
            qualifiedNameIsPath = true;
        };
    }
}
 