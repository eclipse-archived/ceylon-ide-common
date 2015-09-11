import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import java.lang {
    JInteger = Integer
}

class FindScopeVisitor(Integer startOffset, Integer endOffset) extends Visitor() {
    
    variable Node? node = null;
    shared Node? scope => node;
    
    
    shared actual void visit(Tree.Import that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.PackageDescriptor that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.ModuleDescriptor that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.ImportModule that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.InterfaceDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.ClassDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.MethodDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.AttributeGetterDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.AttributeSetterDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.ObjectDefinition that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    
    shared actual void visit(Tree.TypedArgument that) {
        if (inBounds(that)) {
            node = that;
        }
        super.visit(that);
    }
    
    Boolean inBounds(Node? left, Node? right = left) {
        if (!exists left) {
             return false;
        }
        assert(exists left);
        Node newRight = right else left;
        
        JInteger? tokenStart = left.startIndex;
        JInteger? tokenStop = newRight.endIndex;
        
        return if (exists tokenStart, exists tokenStop)
            then tokenStart.intValue() <= startOffset 
                && tokenStop.intValue() >= endOffset
            else false;
    }

}