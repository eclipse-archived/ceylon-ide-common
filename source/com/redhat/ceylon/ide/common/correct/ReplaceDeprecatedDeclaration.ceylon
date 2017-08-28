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
 
     hello(Types.classForType<Foo>)
 "
shared object replaceDeprecatedDeclaration {
    
    value replacements = map {
        "ceylon.interop.java::javaClass" -> "Types.classForType",
        "ceylon.interop.java::javaClassFromInstance" -> "Types.classForInstance",
        "ceylon.interop.java::javaClassFromDeclaration" -> "Types.classForDeclaration",
        "ceylon.interop.java::javaClassFromModel" -> "Types.classForModel",
        "ceylon.interop.java::javaString" -> "Types.nativeString",
        "ceylon.interop.java::javaStackTrace" -> "Types.stackTrace"
    };
    
    shared void addProposal(QuickFixData data, UsageWarning warning) {
        if (warning.warningName == Warning.deprecation.name()) {
            replaceJavaClass(data, warning);
        }
    }
    
    void replaceJavaClass(QuickFixData data, UsageWarning warning) {
        value node = data.node;
        if (is Function decl = nodes.getReferencedModel(node),
            exists newText = replacements.get(decl.qualifiedNameString)
            /*exists invocation = FindInvocationVisitor(data.node).visitCompilationUnit(data.rootNode),
            exists model = invocation.typeModel,
            model.typeArgumentList.size() > 0*/) {
            
            value change = platformServices.document.createTextChange {
                name = "Replace deprecated function call";
                input = data.phasedUnit;
            };
            value oldText = nodes.text(data.tokens, node);
            //value newText = "Types.classForType<``model.typeArgumentList.get(0).asSourceCodeString(node.unit)``>()";
            
            change.addEdit(ReplaceEdit(node.startIndex.intValue(), node.distance.intValue(), newText));
            data.addQuickFix("Replace '``oldText``' with '``newText``'", change);
        }
    }
}
