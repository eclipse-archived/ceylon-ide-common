import com.redhat.ceylon.compiler.typechecker.analyzer {
	UsageWarning,
	Warning
}
import com.redhat.ceylon.ide.common.platform {
	platformServices,
	InsertEdit
}

"Adds missing `maven:` namespaces on deprecated Maven module imports:
 
     import \"org.hibernate:hibernate-core\" \"5.2.2.Final\";

 becomes

     import maven:\"org.hibernate:hibernate-core\" \"5.2.2.Final\";
 "
shared object addNamespaceQuickFix {
	
    shared void addProposal(QuickFixData data, UsageWarning warning ) {
        if (warning.warningName == Warning.missingImportPrefix.name()) {
            value change = platformServices.document.createTextChange {
                name = "Add namespace";
                input = data.phasedUnit;
            };
            change.addEdit(InsertEdit(data.node.startIndex.intValue(), "maven:"));
            data.addQuickFix("Add 'maven:' namespace", change);
        }
    }
}
