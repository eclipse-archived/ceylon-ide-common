import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import java.lang {
    overloaded
}

class FindScopeVisitor(Integer startOffset, Integer endOffset) extends Visitor() {
    
    variable Node? node = null;
    shared Node? scope => node;

    overloaded
    shared actual void visit(Tree.Import that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }


    overloaded
    shared actual void visit(Tree.PackageDescriptor that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ModuleDescriptor that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ImportModule that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.InterfaceDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ClassDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.MethodDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }


    overloaded
    shared actual void visit(Tree.AttributeGetterDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ObjectDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.TypedArgument that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    Boolean inBounds(Node node) 
            => if (exists tokenStart = node.startIndex, 
                   exists tokenEnd = node.endIndex)
            then tokenStart.intValue() <= startOffset 
                && tokenEnd.intValue() >= endOffset
            else false;

}