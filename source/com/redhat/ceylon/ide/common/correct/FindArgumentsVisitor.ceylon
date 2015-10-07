import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    VisitorAdaptor
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    TypedDeclaration,
    ModelUtil
}
class FindArgumentsVisitor(Tree.MemberOrTypeExpression smte) extends VisitorAdaptor() {
    
    shared variable Tree.NamedArgumentList? namedArgs = null;
    shared variable Tree.PositionalArgumentList? positionalArgs = null;
    variable Type? currentType = null;
    shared variable Type? expectedType = null;
    variable value found = false;
    variable value inEnumeration = false;
    
    shared actual void visitMemberOrTypeExpression(Tree.MemberOrTypeExpression that) {
        super.visitMemberOrTypeExpression(that);
        if (that == smte) {
            expectedType = currentType;
            found = true;
        }
    }
    
    shared actual void visitInvocationExpression(Tree.InvocationExpression that) {
        super.visitInvocationExpression(that);
        if (that.primary == smte) {
            namedArgs = that.namedArgumentList;
            positionalArgs = that.positionalArgumentList;
        }
    }
    
    shared actual void visitNamedArgument(Tree.NamedArgument that) {
        value ct = currentType;
        currentType = if (!exists t = that.parameter) then null else that.parameter.type;
        super.visitNamedArgument(that);
        currentType = ct;
    }
    
    shared actual void visitPositionalArgument(Tree.PositionalArgument that) {
        if (inEnumeration) {
            inEnumeration = false;
            super.visitPositionalArgument(that);
            inEnumeration = true;
        } else {
            value ct = currentType;
            currentType = if (!exists t = that.parameter) then null else that.parameter.type;
            super.visitPositionalArgument(that);
            currentType = ct;
        }
    }
    
    shared actual void visitAttributeDeclaration(Tree.AttributeDeclaration that) {
        currentType = that.type.typeModel;
        super.visitAttributeDeclaration(that);
        currentType = null;
    }
    
    shared actual void visitResource(Tree.Resource that) {
        value unit = that.unit;
        currentType = ModelUtil.unionType(unit.destroyableDeclaration.type, unit.obtainableDeclaration.type, unit);
        super.visitResource(that);
        currentType = null;
    }
    
    shared actual void visitBooleanCondition(Tree.BooleanCondition that) {
        currentType = that.unit.booleanDeclaration.type;
        super.visitBooleanCondition(that);
        currentType = null;
    }
    
    shared actual void visitExistsCondition(Tree.ExistsCondition that) {
        value st = that.variable;
        if (is Tree.Variable st) {
            value varType = (st).type.typeModel;
            currentType = that.unit.getOptionalType(varType);
        }
        super.visitExistsCondition(that);
        currentType = null;
    }
    
    shared actual void visitNonemptyCondition(Tree.NonemptyCondition that) {
        value st = that.variable;
        if (is Tree.Variable st) {
            value varType = (st).type.typeModel;
            currentType = that.unit.getEmptyType(varType);
        }
        super.visitNonemptyCondition(that);
        currentType = null;
    }
    
    shared actual void visitExists(Tree.Exists that) {
        value oit = currentType;
        currentType = that.unit.anythingDeclaration.type;
        super.visitExists(that);
        currentType = oit;
    }
    
    shared actual void visitNonempty(Tree.Nonempty that) {
        value unit = that.unit;
        value oit = currentType;
        currentType = unit.getSequentialType(unit.anythingDeclaration.type);
        super.visitNonempty(that);
        currentType = oit;
    }
    
    shared actual void visitSatisfiesCondition(Tree.SatisfiesCondition that) {
        value objectType = that.unit.objectDeclaration.type;
        currentType = objectType;
        super.visitSatisfiesCondition(that);
        currentType = null;
    }
    
    shared actual void visitValueIterator(Tree.ValueIterator that) {
        value varType = that.variable.type.typeModel;
        currentType = that.unit.getIterableType(varType);
        super.visitValueIterator(that);
        currentType = null;
    }
    
    shared actual void visitBinaryOperatorExpression(Tree.BinaryOperatorExpression that) {
        if (!exists c = currentType) {
            Tree.Term? rightTerm = that.rightTerm;
            Tree.Term? leftTerm = that.leftTerm;
            if (exists rightTerm, !ModelUtil.isTypeUnknown(rightTerm.typeModel)) {
                currentType = rightTerm.typeModel;
            }
            if (exists leftTerm) {
                leftTerm.visit(this);
            }
            if (exists leftTerm, !ModelUtil.isTypeUnknown(leftTerm.typeModel)) {
                currentType = leftTerm.typeModel;
            }
            if (exists rightTerm) {
                rightTerm.visit(this);
            }
            currentType = null;
        } else {
            super.visitBinaryOperatorExpression(that);
        }
    }
    
    shared actual void visitEntryOp(Tree.EntryOp that) {
        value unit = that.unit;
        if (exists ct = currentType, ct.declaration.equals(unit.entryDeclaration)) {
            value oit = ct;
            currentType = unit.getKeyType(oit);
            if (exists t = that.leftTerm) {
                that.leftTerm.visit(this);
            }
            currentType = unit.getValueType(oit);
            if (exists t = that.rightTerm) {
                that.rightTerm.visit(this);
            }
            currentType = oit;
        } else {
            value oit = currentType;
            currentType = that.unit.objectDeclaration.type;
            super.visitEntryOp(that);
            currentType = oit;
        }
    }
    
    shared actual void visitRangeOp(Tree.RangeOp that) {
        value unit = that.unit;
        if (exists ct = currentType, unit.isIterableType(ct)) {
            value oit = ct;
            currentType = unit.getIteratedType(oit);
            super.visitRangeOp(that);
            currentType = oit;
        } else {
            value oit = currentType;
            currentType = that.unit.objectDeclaration.type;
            super.visitRangeOp(that);
            currentType = oit;
        }
    }
    
    shared actual void visitSegmentOp(Tree.SegmentOp that) {
        value unit = that.unit;
        if (exists ct = currentType, unit.isIterableType(ct)) {
            value oit = ct;
            currentType = unit.getIteratedType(oit);
            super.visitSegmentOp(that);
            currentType = oit;
        } else {
            value oit = currentType;
            currentType = that.unit.objectDeclaration.type;
            super.visitSegmentOp(that);
            currentType = oit;
        }
    }
    
    shared actual void visitIndexExpression(Tree.IndexExpression that) {
        value unit = that.unit;
        Tree.ElementOrRange? eor = that.elementOrRange;
        Tree.Primary? primary = that.primary;
        value oit = currentType;
        variable value indexType = unit.objectDeclaration.type;
        if (is Tree.Element eor) {
            Tree.Expression? e = eor.expression;
            if (exists e, !ModelUtil.isTypeUnknown(e.typeModel)) {
                indexType = e.typeModel;
            }
        }
        if (is Tree.ElementRange eor) {
            Tree.Expression? l = (eor).lowerBound;
            Tree.Expression? u = (eor).upperBound;
            if (exists l, !ModelUtil.isTypeUnknown(l.typeModel)) {
                indexType = l.typeModel;
            } else if (exists u, !ModelUtil.isTypeUnknown(u.typeModel)) {
                indexType = u.typeModel;
            }
        }
        currentType = ModelUtil.appliedType(unit.correspondenceDeclaration, indexType, unit.getDefiniteType(currentType));
        if (exists primary) {
            primary.visit(this);
        }
        currentType = unit.objectDeclaration.type;
        if (exists primary, !ModelUtil.isTypeUnknown(primary.typeModel)) {
            Type? supertype = primary.typeModel.getSupertype(unit.correspondenceDeclaration);
            if (exists supertype, !supertype.typeArgumentList.empty) {
                currentType = supertype.typeArgumentList.get(0);
            }
        }
        if (exists eor) {
            eor.visit(this);
        }
        currentType = oit;
    }
    
    shared actual void visitLogicalOp(Tree.LogicalOp that) {
        value unit = that.unit;
        value oit = currentType;
        currentType = unit.booleanDeclaration.type;
        super.visitLogicalOp(that);
        currentType = oit;
    }
    
    shared actual void visitBitwiseOp(Tree.BitwiseOp that) {
        value unit = that.unit;
        value oit = currentType;
        currentType = unit.getSetType(unit.objectDeclaration.type).type;
        super.visitBitwiseOp(that);
        currentType = oit;
    }
    
    shared actual void visitNotOp(Tree.NotOp that) {
        value unit = that.unit;
        value oit = currentType;
        currentType = unit.booleanDeclaration.type;
        super.visitNotOp(that);
        currentType = oit;
    }
    
    shared actual void visitInOp(Tree.InOp that) {
        value unit = that.unit;
        value oit = currentType;
        currentType = unit.objectDeclaration.type;
        if (exists t = that.leftTerm) {
            that.leftTerm.visit(this);
        }
        currentType = unit.categoryDeclaration.type;
        if (exists t = that.rightTerm) {
            that.rightTerm.visit(this);
        }
        currentType = oit;
    }
    
    shared actual void visitSequenceEnumeration(Tree.SequenceEnumeration that) {
        value unit = that.unit;
        if (exists ct = currentType, unit.isIterableType(ct)) {
            value oit = ct;
            value oie = inEnumeration;
            inEnumeration = true;
            currentType = unit.getIteratedType(oit);
            super.visitSequenceEnumeration(that);
            currentType = oit;
            inEnumeration = oie;
        } else {
            value oit = currentType;
            currentType = that.unit.anythingDeclaration.type;
            super.visitSequenceEnumeration(that);
            currentType = oit;
        }
    }
    
    shared actual void visitTuple(Tree.Tuple that) {
        value unit = that.unit;
        if (exists ct = currentType, unit.isIterableType(ct)) {
            value oit = ct;
            value oie = inEnumeration;
            inEnumeration = true;
            currentType = unit.getIteratedType(oit);
            super.visitTuple(that);
            currentType = oit;
            inEnumeration = oie;
        } else {
            value oit = currentType;
            currentType = that.unit.anythingDeclaration.type;
            super.visitTuple(that);
            currentType = oit;
        }
    }
    
    shared actual default void visitSpecifierStatement(Tree.SpecifierStatement that) {
        currentType = that.baseMemberExpression.typeModel;
        Tree.SpecifierExpression? se = that.specifierExpression;
        if (exists se) {
            if (ModelUtil.isTypeUnknown(currentType), exists s = se.expression) {
                currentType = se.expression.typeModel;
            }
        } else {
            currentType = null;
        }
        super.visitSpecifierStatement(that);
        currentType = null;
    }
    
    shared actual default void visitAssignmentOp(Tree.AssignmentOp that) {
        value ct = currentType;
        Tree.Term? leftTerm = that.leftTerm;
        Tree.Term? rightTerm = that.rightTerm;
        if (exists leftTerm, exists rightTerm) {
            currentType = leftTerm.typeModel;
            if (ModelUtil.isTypeUnknown(currentType)) {
                currentType = rightTerm.typeModel;
            }
        } else {
            currentType = null;
        }
        super.visitAssignmentOp(that);
        currentType = ct;
    }
    
    shared actual void visitReturn(Tree.Return that) {
        if (is TypedDeclaration decl = that.declaration) {
            currentType = decl.type;
        }
        super.visitReturn(that);
        currentType = null;
    }
    
    shared actual void visitThrow(Tree.Throw that) {
        super.visitThrow(that);
    }
    
    shared actual void visitAny(Node that) {
        if (!found) {
            super.visitAny(that);
        }
    }
    
    shared actual void visitFunctionArgument(Tree.FunctionArgument that) {
        value ct = currentType;
        currentType = null;
        super.visitFunctionArgument(that);
        currentType = ct;
    }
}
