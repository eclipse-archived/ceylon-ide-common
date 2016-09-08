import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    TreeUtil {
        formatPath
    }
}

shared class FindImportNodeVisitor(String packageName) extends Visitor() {

    shared variable Tree.Import? result = null;

    shared actual void visit(Tree.Import that) {
        if (result exists) {
            return;
        }
        value path = formatPath(that.importPath.identifiers);
        if (path == packageName) {
            result = that;
        }
    }

}
