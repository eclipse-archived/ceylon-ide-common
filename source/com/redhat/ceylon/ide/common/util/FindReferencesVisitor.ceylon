import com.redhat.ceylon.compiler.typechecker.tree {
    TreeUtil {
        formatPath
    },
    Node,
    Tree,
    Visitor,
    CustomTree {
        GuardedVariable
    }
}
import com.redhat.ceylon.model.typechecker.model {
    Constructor,
    Declaration,
    Module,
    Package,
    Parameter,
    Referenceable,
    Setter,
    TypedDeclaration
}

import java.util {
    HashSet,
    Set
}

shared class FindReferencesVisitor(shared variable Referenceable declaration) extends Visitor() {
    value _nodes = HashSet<Node>();
    
    shared Set<Node> nodeSet => _nodes;

    if (is TypedDeclaration _d = declaration) {
        variable TypedDeclaration? od = _d;
        
        while (exists _od = od, _od!=declaration) {
            declaration = _od;
            od = _od.originalDeclaration;
        }
    }
    
    if (is Declaration dec = declaration) {
        value container = dec.container;
        if (is Setter container) {
            value setter = container;
            value member = setter.getDirectMember(setter.name, null, false);
            if (member.equals(declaration)) {
                declaration = setter;
            }
        }
    }
    
    if (is Setter setter = declaration) {
        declaration = setter.getter;
    }
    
    if (is Constructor constructor = declaration,
        !declaration.nameAsString exists,
        exists extended = constructor.extendedType) {

        declaration = extended.declaration;
    }
    
    Boolean isReference(Parameter|Declaration? param) {
        if (is Parameter param) {
            return isReference(param.model);
        } else if (is Declaration ref = param) {
            return isRefinedDeclarationReference(ref) || isSetterParameterReference(ref);
        }
        return false;
    }
        
    Boolean isRefinedDeclarationReference(Declaration ref) {
        if (is Declaration dec = declaration) {
            return dec.refines(ref);
        } else {
            return false;
        }
    }
    
    Boolean isSetterParameterReference(Declaration ref) {
        value container = ref.container;
        if (is Setter container) {
            value setter = container;
            value member = setter.getDirectMember(setter.name, null, false);
            return member.equals(ref) && isReference(setter.getter);
        } else {
            return false;
        }
    }
    
    Tree.Variable? getConditionVariable(Tree.Condition c) {
        if (is Tree.ExistsOrNonemptyCondition c) {
            value eonc = c;
            value st = eonc.variable;
            if (is Tree.Variable st) {
                return st;
            }
        }
        
        if (is Tree.IsCondition c) {
            value ic = c;
            return ic.variable;
        }
        
        return null;
    }
    
    shared actual void visit(Tree.CaseClause that) {
        value ci = that.caseItem;
        if (is Tree.IsCase ci) {
            value ic = ci;
            if (exists var = ic.variable) {
                value vd = var.declarationModel;
                if (exists od = vd.originalDeclaration,
                    od.equals(declaration)) {
                    
                    value d = declaration;
                    declaration = vd;
                    if (that.block exists) {
                        that.block.visit(this);
                    }
                    
                    if (that.expression exists) {
                        that.expression.visit(this);
                    }
                    
                    declaration = d;
                    return;
                }
            }
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.WhileClause that) {
        value cl = that.conditionList;
        value conditions = cl.conditions;
        variable value i = 0;
        while (i < conditions.size()) {
            value c = conditions.get(i);
            value var = getConditionVariable(c);
            if (exists var,
                var.type is Tree.SyntheticVariable) {
                
                value vd = var.declarationModel;
                if (exists od = vd.originalDeclaration,
                    od.equals(declaration)) {
                    
                    variable value j = 0;
                    while (j <= i) {
                        value oc = conditions.get(j);
                        oc.visit(this);
                        j++;
                    }
                    
                    value d = declaration;
                    declaration = vd;
                    that.block.visit(this);
                    j = i;
                    while (j < conditions.size()) {
                        value oc = conditions.get(j);
                        oc.visit(this);
                        j++;
                    }
                    
                    declaration = d;
                    return;
                }
            }
            
            i++;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.IfClause that) {
        value cl = that.conditionList;
        value conditions = cl.conditions;
        variable value i = 0;
        
        while (i < conditions.size()) {
            value c = conditions.get(i);
            value var = getConditionVariable(c);
            if (exists var,
                var.type is Tree.SyntheticVariable) {
                
                value vd = var.declarationModel;
                if (exists od = vd.originalDeclaration,
                    od.equals(declaration)) {
                    
                    variable value j = 0;
                    while (j <= i) {
                        value oc = conditions.get(j);
                        oc.visit(this);
                        j++;
                    }
                    
                    value d = declaration;
                    declaration = vd;
                    if (that.block exists) {
                        that.block.visit(this);
                    }
                    
                    if (that.expression exists) {
                        that.expression.visit(this);
                    }
                    
                    j = i + 1;
                    while (j < conditions.size()) {
                        value oc = conditions.get(j);
                        oc.visit(this);
                        j++;
                    }
                    
                    declaration = d;
                    return;
                }
            }
            
            i++;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ElseClause that) {
        if (exists var = that.variable) {
            value vd = var.declarationModel;
            if (exists od = vd.originalDeclaration, od.equals(declaration)) {
                value d = declaration;
                declaration = vd;
                if (that.block exists) {
                    that.block.visit(this);
                }
                
                if (that.expression exists) {
                    that.expression.visit(this);
                }
                
                declaration = d;
                return;
            }
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Variable that) {
        if (is GuardedVariable that) {
            value d = that.declarationModel;
            if (exists od = d.originalDeclaration,
                od.equals(declaration)) {
                
                declaration = d;
            }
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.Body body) {
        value d = declaration;
        for (st in body.statements) {
            if (is Tree.Assertion st) {
                value that = st;
                value cl = that.conditionList;
                for (c in cl.conditions) {
                    value var = getConditionVariable(c);
                    if (exists var,
                        var.type is Tree.SyntheticVariable) {
                        
                        value vd = var.declarationModel;
                        if (exists od = vd.originalDeclaration,
                            od.equals(declaration)) {
                            
                            c.visit(this);
                            declaration = vd;
                            break;
                        }
                    }
                }
            }
            
            st.visit(this);
        }
        
        declaration = d;
    }
    
    shared actual void visit(Tree.ExtendedTypeExpression that) {
    }
    
    shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
        if (isReference(that.declaration)) {
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        if (isReference(that.declaration)) {
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.TypedArgument that) {
        if (isReference(that.parameter)) {
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        if (that.identifier exists, that.identifier.token exists, isReference(that.parameter)) {
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SimpleType that) {
        if (exists type = that.typeModel,
            isReference(type.declaration)) {
            
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ImportMemberOrType that) {
        if (isReference(that.declarationModel)) {
            _nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (is Package pkg = declaration) {
            if (formatPath(that.importPath.identifiers).equals(pkg.nameAsString)) {
                _nodes.add(that);
            }
        }
    }
    
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);

        if (is Module mod = declaration,
            exists path = nodes.getImportedModuleName(that),
            path.equals(declaration.nameAsString)) {
            
            _nodes.add(that);
        }
    }
    
    shared actual void visit(Tree.InitializerParameter that) {
        if (isReference(that.parameterModel)) {
            _nodes.add(that);
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.TypeConstraint that) {
        if (isReference(that.declarationModel)) {
            _nodes.add(that);
        } else {
            super.visit(that);
        }
    }
}
