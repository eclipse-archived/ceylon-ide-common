import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning,
    Warning
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

"Replaces usages of deprecated declarations with known alternatives.
 For example:
 
     hello(javaClass<Foo>())
 
 becomes:
 
     hello(class Foo)
 "
shared object replaceDeprecatedDeclaration {
    
    shared void addProposal(QuickFixData data, UsageWarning warning) {
        if (warning.warningName == Warning.deprecation.name()) {
            replaceJavaClass(data, warning);
        }
    }
    
    void replaceJavaClass(QuickFixData data, UsageWarning warning) {
        if (is Function decl = nodes.getReferencedModel(data.node),
            decl.qualifiedNameString == "ceylon.interop.java::javaClass",
            exists invocation = FindInvocationVisitor(data.node).visitCompilationUnit(data.rootNode),
            exists model = invocation.typeModel,
            model.typeArgumentList.size() > 0) {
            
            value change = platformServices.document.createTextChange {
                name = "Replace javaClass with declaration reference";
                input = data.phasedUnit;
            };
            value oldText = nodes.text(data.tokens, invocation);
            value newText = "class ``model.typeArgumentList.get(0).asSourceCodeString(data.node.unit)``";
            
            change.addEdit(ReplaceEdit(invocation.startIndex.intValue(), invocation.distance.intValue(), newText));
            data.addQuickFix("Replace '``oldText``' with '``newText``'", change);
        }
    }
}
