import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type,
    TypeParameter,
    ModelUtil {
        isTypeUnknown
    }
}

import java.util {
    ArrayList,
    HashSet,
    LinkedHashMap,
    Set
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared class ValueFunctionDefinitionGenerator
        (shared actual String brokenName, shared actual Tree.MemberOrTypeExpression node,
         shared actual Tree.CompilationUnit rootNode, shared actual String description,
         shared actual Icons image, shared actual Type? returnType, 
         shared actual LinkedHashMap<String,Type>? parameters, Boolean? isVariable,
         ImportProposals<out Anything,out Anything,out Anything,out Anything,out Anything,out Anything> importProposals)
        extends DefinitionGenerator() {
    
    
    shared actual String generateShared(String indent, String delim) {
        return "shared " + generateInternal(indent, delim, false);
    }
    
    shared actual String generate(String indent, String delim) {
        return generateInternal(indent, delim, false);
    }
    
    shared actual String generateSharedFormal(String indent, String delim) {
        return "shared formal " + generateInternal(indent, delim, true);
    }
    
    shared actual Boolean isFormalSupported => true;
    
    String generateInternal(String indent, String delim, Boolean isFormal) {
        value def = StringBuilder();
        value isVoid = !(returnType exists);
        value unit = node.unit;
        if (exists parameters) {
            value typeParams = ArrayList<TypeParameter>();
            value typeParamDef = StringBuilder();
            value typeParamConstDef = StringBuilder();
            appendTypeParams2(typeParams, typeParamDef, typeParamConstDef, returnType);
            appendTypeParams3(typeParams, typeParamDef, typeParamConstDef, parameters.values());
            if (typeParamDef.size > 0) {
                typeParamDef.insert(0, "<");
                typeParamDef.deleteTerminal(1);
                typeParamDef.append(">");
            }
            if (isVoid) {
                def.append("void");
            } else {
                if (isTypeUnknown(returnType)) {
                    def.append("function");
                } else {
                    assert(exists returnType);
                    def.append(returnType.asSourceCodeString(unit));
                }
            }
            def.append(" ").append(brokenName).append(typeParamDef.string);
            appendParameters(parameters, def, unit.anythingDeclaration);
            def.append(typeParamConstDef.string);
            if (isFormal) {
                def.append(";");
            } else if (isVoid) {
                def.append(" {}");
            } else {
                def.append(" => ").append(correctionUtil.defaultValue(unit, returnType)).append(";");
            }
        } else {
            if (isVariable else false) {
                def.append("variable ");
            }
            if (isVoid) {
                def.append("Anything");
            } else {
                if (isTypeUnknown(returnType)) {
                    def.append("value");
                } else {
                    assert(exists returnType);
                    def.append(returnType.asSourceCodeString(unit));
                }
            }
            def.append(" ").append(brokenName);
            if (!isFormal) {
                def.append(" = ").append(correctionUtil.defaultValue(unit, returnType));
            }
            def.append(";");
        }
        return def.string;
    }
    
    shared actual Set<Declaration> getImports() {
        value imports = HashSet<Declaration>();
        importProposals.importType(imports, returnType, rootNode);
        if (exists parameters) {
            importProposals.importTypes(imports, parameters.values(), rootNode);
        }
        return imports;
    }
}

class FindValueFunctionVisitor(Tree.MemberOrTypeExpression smte) extends FindArgumentsVisitor(smte) {
    
    shared variable Boolean isVariable = false;
    
    shared actual void visitAssignmentOp(Tree.AssignmentOp that) {
        isVariable = that.leftTerm == smte;
        super.visitAssignmentOp(that);
    }
    
    shared actual void visitUnaryOperatorExpression(Tree.UnaryOperatorExpression that) {
        isVariable = that.term == smte;
        super.visitUnaryOperatorExpression(that);
    }
    
    shared actual void visitSpecifierStatement(Tree.SpecifierStatement that) {
        isVariable = that.baseMemberExpression == smte;
        super.visitSpecifierStatement(that);
    }
}

ValueFunctionDefinitionGenerator? createValueFunctionDefinitionGenerator
        (String brokenName, Tree.MemberOrTypeExpression node, Tree.CompilationUnit rootNode,
        ImportProposals<out Anything,out Anything,out Anything,out Anything,out Anything,out Anything> importProposals) {
    
    value isUpperCase = brokenName.first?.uppercase else false;
    if (isUpperCase) {
        return null;
    }
    value fav = FindValueFunctionVisitor(node);
    rootNode.visit(fav);
    value et = fav.expectedType;
    value isVoid = !(et exists);
    value returnType = if (isVoid) then null else node.unit.denotableType(et);
    value paramTypes = getParameters(fav);
    
    if (exists paramTypes) {
        value desc = "'function " + brokenName + "'";
        return ValueFunctionDefinitionGenerator(brokenName, node, rootNode, desc, 
            Icons.localMethod, returnType, paramTypes, null, importProposals);
    } else {
        value desc = "'value " + brokenName + "'";
        return ValueFunctionDefinitionGenerator(brokenName, node, rootNode, desc,
            Icons.localAttribute, returnType, null, fav.isVariable, importProposals);
    }
}
