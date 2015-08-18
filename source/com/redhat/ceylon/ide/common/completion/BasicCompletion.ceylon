import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Scope
}
import ceylon.collection {
    MutableList
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    escaping
}
shared interface BasicCompletion<IdeComponent, CompletionComponent> {
    
    shared formal CompletionComponent newBasicCompletionProposal(Integer offset, String prefix, 
        String text, String escapedText, Declaration decl, IdeComponent cmp);
    
    shared void addImportProposal(Integer offset, String prefix, IdeComponent cpc, MutableList<CompletionComponent> result,
            Declaration dec, Scope scope) {
        result.add(newBasicCompletionProposal(offset, prefix, dec.name, escaping.escapeName(dec), dec, cpc));
    }
    
    shared void addDocLinkProposal(Integer offset, String prefix, IdeComponent cpc, MutableList<CompletionComponent> result,
            Declaration dec, Scope scope, Tree.CompilationUnit cu) {
        String name = dec.name;
        String aliasedName = dec.getName(cu.unit);
        if (!name.equals(aliasedName)) {
            result.add(newBasicCompletionProposal(offset, prefix, aliasedName, aliasedName, dec, cpc));
        }
        result.add(newBasicCompletionProposal(offset, prefix, name, getTextForDocLink(cu.unit, dec), dec, cpc));
    }

}