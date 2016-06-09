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
    TypedDeclaration,
    FunctionOrValue
}

import java.util {
    HashSet,
    Set
}

shared class FindReferencesVisitor(Referenceable dec) extends Visitor() {
    shared Set<Node> nodeSet = HashSet<Node>();
    
    function initialDeclaration(Referenceable dec) {
        if (is TypedDeclaration dec) {
            variable TypedDeclaration result = dec;
            while (exists original = result.originalDeclaration, 
                original!=result && original!=dec) {
                result = original;
            }
            if (is Setter setter = result.container,
                is FunctionOrValue res = result, 
                exists param = res.initializerParameter,
                param.declaration==result) {
                result = setter;
            }
            if (is Setter setter = result,
                exists getter = setter.getter) {
                result = getter;
            }
            return result;
        }
        else if (is Constructor dec, !dec.name exists,
            exists extended = dec.extendedType) {
            return extended.declaration;
        }    
        else {
            return dec;
        }
    }
    
    shared variable Referenceable declaration 
            = initialDeclaration(dec);
    
    shared default Boolean isReference(Parameter|Declaration? param) {
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
        if (is Setter setter = ref.container) {
            value member = setter.getDirectMember(setter.name, null, false);
            return member==ref && isReference(setter.getter);
        } else {
            return false;
        }
    }
    
    Tree.Variable? getConditionVariable(Tree.Condition c) {
        if (is Tree.ExistsOrNonemptyCondition eonc = c, 
            is Tree.Variable st = eonc.variable) {
            
            return st;
        }
        
        if (is Tree.IsCondition ic = c) {
            return ic.variable;
        }
        
        return null;
    }
    
    shared actual void visit(Tree.CaseClause that) {
        if (is Tree.IsCase ic = that.caseItem,
            exists var = ic.variable) {
            
            value vd = var.declarationModel;
            if (exists od = vd.originalDeclaration,
                od==declaration) {
                
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
    
    shared actual void visit(Tree.WhileClause that) {
        if (exists cl = that.conditionList) {
            value conditions = cl.conditions;
            variable value i = 0;
            while (i < conditions.size()) {
                value c = conditions.get(i);
                value var = getConditionVariable(c);
                if (exists var,
                    var.type is Tree.SyntheticVariable) {
                    
                    value vd = var.declarationModel;
                    if (exists od = vd.originalDeclaration,
                        od==declaration) {
                        
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
        }

        super.visit(that);
    }
    
    shared actual void visit(Tree.IfClause that) {
        if (exists cl = that.conditionList) {
            value conditions = cl.conditions;
            
            variable value i = 0;
            while (i < conditions.size()) {
                value c = conditions.get(i);
                value var = getConditionVariable(c);
                if (exists var,
                    var.type is Tree.SyntheticVariable) {
                    
                    value vd = var.declarationModel;
                    if (exists od = vd.originalDeclaration,
                        od==declaration) {
                        
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
        }

        super.visit(that);
    }
    
    shared actual void visit(Tree.ElseClause that) {
        if (exists var = that.variable) {
            value vd = var.declarationModel;
            if (exists od = vd.originalDeclaration, 
                od==declaration) {
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
                od==declaration) {
                
                declaration = d;
            }
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.Body body) {
        value d = declaration;
        for (st in body.statements) {
            if (is Tree.Assertion  that = st) {
                value cl = that.conditionList;
                for (c in cl.conditions) {
                    value var = getConditionVariable(c);
                    if (exists var,
                        var.type is Tree.SyntheticVariable) {
                        
                        value vd = var.declarationModel;
                        if (exists od = vd.originalDeclaration,
                            od==declaration) {
                            
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
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        if (isReference(that.declaration)) {
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.TypedArgument that) {
        if (isReference(that.parameter)) {
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        if (that.identifier exists, 
            that.identifier.token exists, 
            isReference(that.parameter)) {
            
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SimpleType that) {
        if (exists type = that.typeModel,
            isReference(type.declaration)) {
            
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ImportMemberOrType that) {
        if (isReference(that.declarationModel)) {
            nodeSet.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (is Package pkg = declaration) {
            value path = formatPath(that.importPath.identifiers);
            if (path==pkg.nameAsString) {
                nodeSet.add(that);
            }
        }
    }
    
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);
        
        if (is Module mod = declaration,
            exists path = nodes.getImportedModuleName(that),
            path==declaration.nameAsString) {
            
            nodeSet.add(that);
        }
    }
    
    shared actual default void visit(Tree.InitializerParameter that) {
        if (isReference(that.parameterModel)) {
            nodeSet.add(that);
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.TypeConstraint that) {
        if (isReference(that.declarationModel)) {
            nodeSet.add(that);
        } else {
            super.visit(that);
        }
    }
}
