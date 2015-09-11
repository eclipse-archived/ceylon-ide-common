import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree {
        Term
    }
}
import java.util {
    List
}
import org.antlr.runtime {
    CommonToken
}

"Finds the smallest (most specific) node where a given selection
 is completely within bounds of that node (plus whitespace)."
shared class FindNodeVisitor(tokens, startOffset, endOffset) extends Visitor() {
    
    """The list of all tokens in the compilation unit.
       If this is non-[[null]], it's used to improve the search:
       
           print(    "Hello, World!"    );
           //      <----------------->
       
       With tokens, we can determine that the string literal is the selected node,
       even though the selection is not within bounds of the literal itself."""
    List<CommonToken>? tokens;
    
    "The index of the first selected character."
    Integer startOffset;
    
    "The index of the first character past the selection,
     or (equivalently) [[startOffset]] plus the length of the selection,
     or (equivalently) the index of the last selected character *plus one*.
     
     For example, if the selection is empty, this is the same as [[startOffset]];
     if a single character is selected, this is `startOffset + 1`."
    Integer endOffset;
    
    "The result: the most specific node for which the selection
     specified by [[startOffset]] and [[endOffset]]
     is contained within this [[node]] and whitespace surrounding it."
    shared variable Node? node = null;
    
    Boolean inBounds(Node? left, Node? right = left) {
        if (exists left) {
            function shouldReplacePreviousNode(Boolean isInBounds) {
                if (isInBounds == false) {
                    return false;
                }
                if (startOffset != endOffset) {
                    return isInBounds;
                }
                if (exists previousNode=node,
                    exists previousNodeEnd=previousNode.endIndex?.intValue(),
                    exists leftNodeStart=left.startIndex?.intValue(),
                    previousNodeEnd<=leftNodeStart) {
                    return false;
                }
                return true;
            }

            value rightNode = right else left;
            
            assert (is CommonToken? startToken = left.token,
                is CommonToken? endToken = rightNode.endToken else rightNode.token);
            
            if (exists startToken, exists endToken) {
                if (exists tokens) {
                    if (startToken.tokenIndex > 0) {
                        if (startToken.startIndex > endOffset) {
                            return false;
                        }
                        if (startToken.startIndex > startOffset) {
                            // we could still consider this in bounds
                            // if the tokens between startOffset and startToken were only hidden ones
                            for (index in (startToken.tokenIndex-1)..0) {
                                value token = tokens.get(index);
                                if (token.channel != CommonToken.\iHIDDEN_CHANNEL) {
                                    return false;
                                }
                                if (token.startIndex <= startOffset) {
                                    break;
                                }
                            }
                        }
                    }
                    if (endToken.tokenIndex < tokens.size() - 1) {
                        if (endToken.stopIndex+1 < startOffset) {
                            return false;
                        }
                        if (endToken.stopIndex+1 < endOffset) {
                            // we could still consider this in bounds
                            // if the tokens between endToken and endOffset were only hidden ones
                            for (index in (endToken.tokenIndex+1)..(tokens.size()-1)) {
                                value token = tokens.get(index);
                                if (token.channel != CommonToken.\iHIDDEN_CHANNEL) {
                                    return false;
                                }
                                if (token.stopIndex+1 >= endOffset) {
                                    break;
                                }
                            }
                        }
                    }
                    return shouldReplacePreviousNode {
                                isInBounds = true;
                            };
                } else {
                    if (exists startTokenOffset = left.startIndex?.intValue(),
                        exists endTokenOffset = rightNode.endIndex?.intValue()) {
                        return shouldReplacePreviousNode {
                                    isInBounds = startTokenOffset <= startOffset
                                            && endOffset <= endTokenOffset;
                                };
                    } else {
                        return false;
                    }
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
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
        if (exists ie, exists args = ie.positionalArgumentList) {
            args.visit(this);
        }
        
        if (!exists t, !exists ie) {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.ClassSpecifier that) {
        Tree.SimpleType? t = that.type;
        if (exists t) {
            t.visit(this);
        }
        Tree.InvocationExpression? ie = that.invocationExpression;
        if (exists ie, exists args = ie.positionalArgumentList) {
            args.visit(this);
        }
        
        if (!exists t, !exists ie) {
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
        //otherwise, as a performance optimization
        //don't go any further down this branch
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
    
    shared actual void visit(Tree.MemberOperator that) {
    }
    
    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        if (inBounds(that.memberOperator, that.identifier)) {
            node=that;
        }
        super.visit(that);
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