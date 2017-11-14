/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    MutableList
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree {
        ...
    }
}

import java.util {
    JList=List,
    Collections
}

Boolean different(Tree.Term? term, Tree.Term? expression, 
        localRefs = [], arguments = null) {
    List<Tree.BaseMemberExpression> localRefs;
    "Note: function modifies this given list by side-effect!"
    MutableList<Tree.Term>? arguments;
    
    if (!exists term) {
        return true;
    }
    if (!exists expression) {
        return true;
    }
    if (is Expression term) {
        return different(term.term, expression, localRefs, arguments);
    }
    if (is Expression expression) {
        return different(term, expression.term, localRefs, arguments);
    }
    
    if (exists tt = term.typeModel, 
        exists et = expression.typeModel) {
        if (!et.isSubtypeOf(tt)) {
            return true;
        }
    }
    else {
        return true;
    }
    
    if (exists arguments) {
        if (term in localRefs) {
            arguments.add(expression);
            return false;
        }
    }
    
    if (term.nodeType!=expression.nodeType) {
        return true;
    }
    
    function positionalArgsDifferent(x, y) {
        JList<PositionalArgument> y;
        JList<PositionalArgument> x;
        value xsize = x.size();
        value ysize = y.size();
        if (xsize!=ysize) {
            return true;
        }
        for (i in 0:xsize) {
            value xi = x[i];
            value yi = y[i];
            if (is ListedArgument xi, is ListedArgument yi) {
                if (different(xi.expression, yi.expression, localRefs, arguments)) {
                    return true;
                }
            }
            else {
                return true;
            }
        }
        return false;
    }
    function namedArgsDifferent(x, y) {
        JList<NamedArgument> y;
        JList<NamedArgument> x;
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
                if (xp!=yp || different(xse, yse, localRefs, arguments)) {
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
        if (term is Tree.SumOp|Tree.ProductOp|Tree.UnionOp|Tree.IntersectionOp|Tree.EqualOp|Tree.NotEqualOp) {
            return (different(term.leftTerm, expression.leftTerm, localRefs, arguments) ||
                different(term.rightTerm, expression.rightTerm, localRefs, arguments)) &&
                    (different(term.leftTerm, expression.rightTerm, localRefs, arguments) ||
                different(term.rightTerm, expression.leftTerm, localRefs, arguments));
        }
        else {
            return different(term.leftTerm, expression.leftTerm, localRefs, arguments) ||
                    different(term.rightTerm, expression.rightTerm, localRefs, arguments);
        }
    }
    case (is UnaryOperatorExpression) {
        assert (is UnaryOperatorExpression expression);
        return different(term.term, expression.term, localRefs, arguments);
    }
    case (is WithinOp) {
        assert (is WithinOp expression);
        return different(term.term, expression.term, localRefs, arguments) || 
                different(term.upperBound, expression.upperBound, localRefs, arguments) || 
                different(term.lowerBound, expression.lowerBound, localRefs, arguments);
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
            then tt.declaration!=et.declaration 
            else true;
    }
    case (is QualifiedMemberOrTypeExpression) {
        assert (is QualifiedMemberOrTypeExpression expression);
        return 
        if (exists tt = term.target, 
            exists et = expression.target,
            exists tmo = term.memberOperator,
            exists emo = expression.memberOperator)
        then tt.declaration!=et.declaration || 
                different(term.primary, expression.primary, localRefs, arguments) ||
                tmo.nodeType!=emo.nodeType
        else true;
    }
    case (is SelfExpression) {
        assert (is SelfExpression expression);
        return term.declarationModel!=expression.declarationModel;
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
        if (different(term.primary, expression.primary, localRefs, arguments)) {
            return true;
        }
        if (exists tpal = term.positionalArgumentList,
            exists epal = expression.positionalArgumentList) {
            value ts = tpal.positionalArguments;
            value es = epal.positionalArguments;
            return positionalArgsDifferent(ts, es);
        }
        if (exists tnal = term.namedArgumentList,
            exists enal = expression.namedArgumentList) {
            value noArgs = Collections.emptyList<Tree.PositionalArgument>();
            value ts = tnal.sequencedArgument?.positionalArguments else noArgs;
            value es = enal.sequencedArgument?.positionalArguments else noArgs;
            value tns = tnal.namedArguments;
            value ens = enal.namedArguments;
            return positionalArgsDifferent(ts, es) 
                || namedArgsDifferent(tns, ens);
        }
        return true;
    }
    else {
        //things we don't know how to handle yet!
        return true;
    }
    
}
