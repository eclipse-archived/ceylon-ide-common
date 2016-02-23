import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}

class FindArgumentContextVisitor(Node term) extends Visitor() {
    
    shared variable [Tree.InvocationExpression?, Tree.SequencedArgument?, Tree.NamedArgument|Tree.PositionalArgument?]? context = null;
    
    variable Tree.NamedArgument|Tree.PositionalArgument? currentArgument = null;
    variable Tree.SequencedArgument? currentSequencedArgument = null; 
    variable Tree.InvocationExpression? currentInvocation = null;
    
    alias InvocationArgument => Tree.NamedArgument|Tree.PositionalArgument;
    
    shared actual void visit(Tree.NamedArgument that) {
        InvocationArgument? myOuter = currentArgument;
        currentArgument = that;
        super.visit(that);
        currentArgument = myOuter;
	}
    
    shared actual void visit(Tree.PositionalArgument that) {
        InvocationArgument? myOuter = currentArgument;
        currentArgument = that;
        super.visit(that);
        currentArgument = myOuter;
	}
    
    shared actual void visit(Tree.SequencedArgument that) {
        currentSequencedArgument = that;
        super.visit(that);
        currentSequencedArgument = null;
	}
    
    shared actual void visit(Tree.InvocationExpression that) {
        Tree.InvocationExpression? myOuter = currentInvocation;
        Tree.SequencedArgument? myOuterSequencedArgument = currentSequencedArgument;
        currentInvocation = that;
        super.visit(that);
        currentInvocation = myOuter;
        currentSequencedArgument = myOuterSequencedArgument;
	}
	
    shared actual void visitAny(Node node) {
        if (node == term) {
            context = [currentInvocation, currentSequencedArgument, currentArgument];
        }
        
        if (!exists c = context) {
            super.visitAny(node);
        }
    }
}