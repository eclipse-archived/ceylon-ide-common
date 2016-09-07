import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

import java.util {
    Arrays
}

shared class FindImportNodeVisitor(String packageName) extends Visitor() {

    shared variable Tree.Import? result = null;

    shared actual void visit(Tree.Import that) {
        if (result exists) {
            return;
        }
        value ids
                = Arrays.asList(
                    for (id in that.importPath.identifiers)
                    javaString(id.text));
        if (ModelUtil.formatPath(ids) == packageName) {
            result = that;
        }
    }

}
