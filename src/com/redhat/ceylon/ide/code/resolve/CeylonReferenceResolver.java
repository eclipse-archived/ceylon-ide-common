package com.redhat.ceylon.ide.code.resolve;

import com.redhat.ceylon.compiler.typechecker.model.Declaration;
import com.redhat.ceylon.compiler.typechecker.model.Parameter;
import com.redhat.ceylon.compiler.typechecker.tree.Node;
import com.redhat.ceylon.compiler.typechecker.tree.Tree;

import java.util.List;

public class CeylonReferenceResolver {
    public static Declaration getReferencedExplicitDeclaration(Node node, Tree.CompilationUnit rn) {
        Declaration dec = getReferencedDeclaration(node);
        if (dec!=null && dec.getUnit().equals(node.getUnit())) {
            FindDeclarationNodeVisitor fdv = new FindDeclarationNodeVisitor(dec);
            fdv.visit(rn);
            Node decNode = fdv.getDeclarationNode();
            if (decNode instanceof Tree.Variable) {
                Tree.Variable var = (Tree.Variable) decNode;
                if (var.getType() instanceof Tree.SyntheticVariable) {
                    return getReferencedExplicitDeclaration(
                            var.getSpecifierExpression().getExpression().getTerm(),
                            rn);
                }
            }
        }
        return dec;
    }

    public static Declaration getReferencedDeclaration(Node node) {
        //NOTE: this must accept a null node, returning null!
        if (node instanceof Tree.MemberOrTypeExpression) {
            return ((Tree.MemberOrTypeExpression) node).getDeclaration();
        }
        else if (node instanceof Tree.SimpleType) {
            return ((Tree.SimpleType) node).getDeclarationModel();
        }
        else if (node instanceof Tree.ImportMemberOrType) {
            return ((Tree.ImportMemberOrType) node).getDeclarationModel();
        }
        else if (node instanceof Tree.Declaration) {
            return ((Tree.Declaration) node).getDeclarationModel();
        }
        else if (node instanceof Tree.NamedArgument) {
            Parameter p = ((Tree.NamedArgument) node).getParameter();
            return p==null ? null : p.getModel();
        }
        else if (node instanceof Tree.InitializerParameter) {
            Parameter p = ((Tree.InitializerParameter) node).getParameterModel();
            return  p==null ? null : p.getModel();
        }
        else if (node instanceof Tree.MetaLiteral) {
            return ((Tree.MetaLiteral) node).getDeclaration();
        }
        else if (node instanceof Tree.DocLink) {
            Tree.DocLink docLink = (Tree.DocLink) node;
            List<Declaration> qualified = docLink.getQualified();
            if (qualified!=null && !qualified.isEmpty()) {
                return qualified.get(qualified.size()-1);
            }
            else {
                return docLink.getBase();
            }
        }
        else {
            return null;
        }
    }
}
