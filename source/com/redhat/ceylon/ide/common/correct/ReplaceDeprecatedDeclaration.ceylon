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
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
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
        if (is Tree.Identifier id = nodes.getIdentifyingNode(data.node),
            is Function decl = nodes.getReferencedModel(data.node),
            exists newText = replacements.get(decl.qualifiedNameString)) {
            
            value change = platformServices.document.createTextChange {
                name = "Replace Deprecated Function";
                input = data.phasedUnit;
            };
            value oldText = nodes.text(data.tokens, id);

            change.addEdit(ReplaceEdit {
                start = id.startIndex.intValue();
                length = id.distance.intValue();
                text = newText;
            });
            data.addQuickFix("Replace '``oldText``()' with '``newText``()'", change);
        }
    }
}
