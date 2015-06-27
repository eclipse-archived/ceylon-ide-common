import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree {
        Identifier
    }
}
import ceylon.interop.java {
    CeylonIterable
}

shared class FindImportNodeVisitor(String packageName) extends Visitor() {

    shared variable Tree.Import? result = null;
    value packageNameComponents = packageName.split('.'.equals);
    
    shared actual void visit(Tree.Import that) {
        if (exists r = result) {
            return;
        }
        
        if (identifiersEqual(CeylonIterable(that.importPath.identifiers), packageNameComponents)) {
            result = that;
        }
    }
    
    Boolean identifiersEqual({Tree.Identifier*} identifiers, {String+} components) {
        return identifiers.map((id) => id.text).sequence() == components.sequence();
    }
}
