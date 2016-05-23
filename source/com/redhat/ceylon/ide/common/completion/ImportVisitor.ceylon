import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor
}

import org.antlr.runtime {
    CommonToken
}

class ImportVisitor(String prefix, CommonToken token, Integer offset, Node node,
    CompletionContext ctx, BaseProgressMonitor monitor)
        extends Visitor() {
    
    shared actual void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(ctx, offset, text);
        }
    }
    shared actual void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(ctx, offset, text);
        }
    }
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions(ctx, offset, prefix, node, node,
                nextTokenType(ctx, token) != CeylonLexer.\iLBRACE, monitor);
        }
    }
    shared actual void visit(Tree.PackageLiteral that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions(ctx, offset, prefix, node, node, false, monitor);
        }
    }
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            value withBody = nextTokenType(ctx, token) != CeylonLexer.\iSTRING_LITERAL;
            completionManager.addModuleCompletions(ctx, offset, prefix, node, node, withBody, monitor);
        }
    }
    shared actual void visit(Tree.ModuleLiteral that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addModuleCompletions(ctx, offset, prefix, node, node, false, monitor);
        }
    }
}
