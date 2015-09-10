import ceylon.collection {
    MutableList
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    ProgressMonitor
}
import org.antlr.runtime {
    CommonToken
}

class ImportVisitor<IdeComponent,IdeArtifact,CompletionComponent,Document>(String prefix, CommonToken token, Integer offset, Node node,
    IdeComponent cpc, MutableList<CompletionComponent> result, ProgressMonitor monitor,
    IdeCompletionManager<IdeComponent,IdeArtifact,CompletionComponent,Document> completionManager)
        extends Visitor()
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared actual void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        if (that.importPath == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(cpc, offset, text, result);
        }
    }
    shared actual void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        if (that.importPath == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(cpc, offset, text, result);
        }
    }
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (that.importPath == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions(cpc, offset, prefix, node, node, result,
                nextTokenType(cpc, token) != CeylonLexer.\iLBRACE, monitor);
        }
    }
    shared actual void visit(Tree.PackageLiteral that) {
        super.visit(that);
        if (that.importPath == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions(cpc, offset, prefix, node, node, result, false, monitor);
        }
    }
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);
        if (that.importPath == node) {
            assert (is Tree.ImportPath node);
            value withBody = nextTokenType(cpc, token) != CeylonLexer.\iSTRING_LITERAL;
            completionManager.addModuleCompletions(cpc, offset, prefix, node, node, result, withBody, monitor);
        }
    }
    shared actual void visit(Tree.ModuleLiteral that) {
        super.visit(that);
        if (that.importPath == node) {
            assert (is Tree.ImportPath node);
            completionManager.addModuleCompletions(cpc, offset, prefix, node, node, result, false, monitor);
        }
    }
}
