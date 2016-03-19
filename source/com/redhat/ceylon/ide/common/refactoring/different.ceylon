import java.util {
    JList=List
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree { ... }
}

Boolean different(Tree.Term? term, Tree.Term? expression) {
    if (!exists term) {
        return true;
    }
    if (!exists expression) {
        return true;
    }
    if (term.nodeType!=expression.nodeType) {
        return true;
    }
    function positionalArgsDifferent(JList<PositionalArgument> x, JList<PositionalArgument> y) {
        value xsize = x.size();
        value ysize = y.size();
        if (xsize!=ysize) {
            return true;
        }
        for (i in 0:xsize) {
            value xi = x[i];
            value yi = y[i];
            if (is ListedArgument xi, is ListedArgument yi) {
                if (different(xi.expression, yi.expression)) {
                    return true;
                }
            }
            else {
                return true;
            }
        }
        return false;
    }
    function namedArgsDifferent(JList<NamedArgument> x, JList<NamedArgument> y) {
        value xsize = x.size();
        value ysize = y.size();
        if (xsize!=ysize) {
            return true;
        }
        for (i in 0:xsize) {
            value xi = x[i];
            value yi = y[i];
            if (is SpecifiedArgument xi, is SpecifiedArgument yi,
                exists xse = xi.specifierExpression?.expression,
                exists yse = yi.specifierExpression?.expression,
                exists xp = xi.parameter?.declaration, 
                exists yp = yi.parameter?.declaration) {
                if (xp!=yp || different(xse, yse)) {
                    return true;
                }
            }
            else {
                return true;
            }
        }
        return false;
    }
    switch (term) 
    case (is BinaryOperatorExpression) {
        assert (is BinaryOperatorExpression expression);
        return different(term.leftTerm, expression.leftTerm) ||
                different(term.rightTerm, expression.rightTerm);
    }
    case (is UnaryOperatorExpression) {
        assert (is UnaryOperatorExpression expression);
        return different(term.term, expression.term);
    }
    case (is WithinOp) {
        assert (is WithinOp expression);
        return different(term.term, expression.term) || 
                different(term.upperBound, expression.upperBound) || 
                different(term.lowerBound, expression.lowerBound);
    }
    case (is Literal) {
        assert (is Literal expression);
        return term.text!=expression.text;
    }
    case (is BaseMemberOrTypeExpression) {
        assert (is BaseMemberOrTypeExpression expression);
        return 
        if (exists tt = term.target, 
            exists et = expression.target) 
            then tt!=et else true;
    }
    case (is QualifiedMemberOrTypeExpression) {
        assert (is QualifiedMemberOrTypeExpression expression);
        return 
        if (exists tt = term.target, 
            exists et = expression.target,
            exists tmo = term.memberOperator,
            exists emo = expression.memberOperator)
        then tt.declaration!=et.declaration || 
                different(term.primary, expression.primary) ||
                tmo.nodeType!=emo.nodeType
        else true;
    }
    case (is SelfExpression) {
        return false;
    }
    case (is Tuple) {
        assert (is Tuple expression);
        return positionalArgsDifferent(term.sequencedArgument.positionalArguments, 
                    expression.sequencedArgument.positionalArguments);
    }
    case (is SequenceEnumeration) {
        assert (is SequenceEnumeration expression);
        return positionalArgsDifferent(term.sequencedArgument.positionalArguments, 
                    expression.sequencedArgument.positionalArguments);
    }
    case (is TypeLiteral) {
        assert (is TypeLiteral expression);
        if (exists ttt = term.type?.typeModel,
            exists ett = expression.type?.typeModel) {
            return ttt!=ett;
        }
        else {
            return true;
        }
    }
    case (is MemberLiteral) {
        assert (is MemberLiteral expression);
        if (exists ttt = term.type?.typeModel,
            exists ett = expression.type?.typeModel, 
            exists tt = term.target, 
            exists et = expression.target) {
            return ttt!=ett || tt!=et;
        }
        else {
            return true;
        }
    }
    case (is PackageLiteral) {
        assert (is PackageLiteral expression);
        if (exists tm = term.importPath?.model,
            exists em = expression.importPath?.model) {
            return tm!=em;
        }
        else {
            return true;
        }
    }
    case (is ModuleLiteral) {
        assert (is ModuleLiteral expression);
        if (exists tm = term.importPath?.model,
            exists em = expression.importPath?.model) {
            return tm!=em;
        }
        else {
            return true;
        }
    }
    case (is InvocationExpression) {
        assert (is InvocationExpression expression);
        if (different(term.primary, expression.primary)) {
            return true;
        }
        if (exists tp = term.positionalArgumentList,
            exists ep = expression.positionalArgumentList) {
            return positionalArgsDifferent(term.positionalArgumentList.positionalArguments,
                        expression.positionalArgumentList.positionalArguments);
        }
        if (exists tp = term.namedArgumentList,
            exists ep = expression.namedArgumentList) {
            return positionalArgsDifferent(term.namedArgumentList.sequencedArgument.positionalArguments,
                        expression.namedArgumentList.sequencedArgument.positionalArguments) ||
                    namedArgsDifferent(term.namedArgumentList.namedArguments, expression.namedArgumentList.namedArguments);
        }
        return true;
    }
    else {
        //things we don't know how to handle yet!
        return true;
    }
    
}