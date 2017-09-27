import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import org.eclipse.ceylon.ide.common.util {
    BaseProgressMonitor
}

import org.antlr.runtime {
    CommonToken
}
import java.lang {
    overloaded
}

class ImportVisitor(String prefix, CommonToken token, Integer offset, Node node,
    CompletionContext ctx, BaseProgressMonitor monitor)
        extends Visitor() {

    overloaded
    shared actual void visit(Tree.ModuleDescriptor that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(ctx, offset, text);
        }
    }

    overloaded
    shared actual void visit(Tree.PackageDescriptor that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            value text = fullPath(offset, prefix, that.importPath) + prefix;
            completionManager.addCurrentPackageNameCompletion(ctx, offset, text);
        }
    }

    overloaded
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = node;
                node = node;
                withBody = nextTokenType(ctx, token) != CeylonLexer.lbrace;
                monitor = monitor;
            };
        }
    }

    overloaded
    shared actual void visit(Tree.PackageLiteral that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addPackageCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = node;
                node = node;
                withBody = false;
                monitor = monitor;
            };
        }
    }

    overloaded
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            value withBody = nextTokenType(ctx, token) != CeylonLexer.stringLiteral;
            completionManager.addModuleCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = node;
                node = node;
                withBody = withBody;
                monitor = monitor;
            };
        }
    }

    overloaded
    shared actual void visit(Tree.ModuleLiteral that) {
        super.visit(that);
        if (exists path = that.importPath,
            path == node) {
            assert (is Tree.ImportPath node);
            completionManager.addModuleCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = node;
                node = node;
                withBody = false;
                monitor = monitor;
                addNamespaceProposals = false;
            };
        }
    }
}
