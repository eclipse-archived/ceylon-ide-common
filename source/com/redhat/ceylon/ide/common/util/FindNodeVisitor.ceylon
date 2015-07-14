import com.redhat.ceylon.compiler.typechecker.tree {
	Visitor,
	NaturalVisitor,
	Node,
	Tree {
		Term
	}
}

shared class FindNodeVisitor(Integer startOffset, Integer endOffset) extends Visitor() satisfies NaturalVisitor {
	
	shared variable Node? node = null;
	
	Boolean inBounds(Node? left, Node? right = left) {
		if (exists left) {
			value rightNode = right else left; 
			Integer? tokenStartIndex = left.startIndex?.intValue();
			Integer? tokenStopIndex = rightNode.stopIndex?.intValue();
			
			if (exists tokenStartIndex, exists tokenStopIndex) {
				return tokenStartIndex <= startOffset && tokenStopIndex+1 >= endOffset;
			}
		}
		
		return false;
	}
	
	shared actual void visit(Tree.MemberLiteral that) {
		if (inBounds(that.identifier)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.ExtendedType that) {
		Tree.SimpleType? t = that.type;
		if (exists t) {
			t.visit(this);
		}
		Tree.InvocationExpression? ie = that.invocationExpression;
		if (exists ie) {
			ie.positionalArgumentList.visit(this);
		}
		
		if (!exists t, exists ie) {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.ClassSpecifier that) {
		Tree.SimpleType? t = that.type;
		if (exists t) {
			t.visit(this);
		}
		Tree.InvocationExpression? ie = that.invocationExpression;
		if (exists ie) {
			ie.positionalArgumentList.visit(this);
		}
		
		if (!exists t, exists ie) {
			super.visit(that);
		}
	}
	
	shared actual void visitAny(Node that) {
		if (inBounds(that)) {
			if (!is Tree.LetClause that) {
				node = that;
			}
			super.visitAny(that);
		}
	}
	
	shared actual void visit(Tree.ImportPath that) {
		if (inBounds(that)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.BinaryOperatorExpression that) {
		Term right = that.rightTerm else that;
		Term left = that.leftTerm else that;
		
		if (inBounds(left, right)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.UnaryOperatorExpression that) {
		Term term = that.term else that;
		if (inBounds(that, term) || inBounds(term, that)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.ParameterList that) {
		if (inBounds(that)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.TypeParameterList that) {
		if (inBounds(that)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.ArgumentList that) {
		if (inBounds(that)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.TypeArgumentList that) {
		if (inBounds(that)) {
			node=that;
		}
		super.visit(that);
	}
	
	shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
		if (inBounds(that.memberOperator, that.identifier)) {
			node=that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
		if (inBounds(that.identifier)) {
			node = that;
			//Note: we can't be sure that this is "really"
			//      an EXPRESSION!
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.SimpleType that) {
		if (inBounds(that.identifier)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.ImportMemberOrType that) {
		if (inBounds(that.identifier) || inBounds(that.\ialias)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.Declaration that) {
		if (inBounds(that.identifier)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.InitializerParameter that) {
		if (inBounds(that.identifier)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.NamedArgument that) {
		if (inBounds(that.identifier)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
	shared actual void visit(Tree.DocLink that) {
		if (inBounds(that)) {
			node = that;
		}
		else {
			super.visit(that);
		}
	}
	
}