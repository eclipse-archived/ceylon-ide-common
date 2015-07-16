import com.redhat.ceylon.compiler.typechecker.tree {
	Node,
	Tree
}
import com.redhat.ceylon.model.typechecker.model {
	Referenceable,
	Parameter,
    Unit,
    ModelUtil
}
import ceylon.interop.java {
	CeylonList,
    CeylonIterable
}

shared object nodes {

    shared Node? getReferencedNode(Referenceable? model) {
        if (exists model) {
            if (is Unit unit = model.unit) {
                
            }
        }
        
        return null;
    }
    
    shared Tree.Statement? findStatement(Tree.CompilationUnit cu, Node node) {
        value fsv = FindStatementVisitor(node, false);
        cu.visit(fsv);
        return fsv.statement;
    }

    shared Tree.Statement? findTopLebelStatement(Tree.CompilationUnit cu, Node node) {
        value fsv = FindStatementVisitor(node, true);
        cu.visit(fsv);
        return fsv.statement;
    }
    
	shared Node? findNode(Tree.CompilationUnit cu, Integer offset) {
		FindNodeVisitor visitor = FindNodeVisitor(offset, offset + 1);
		
		cu.visit(visitor);
		
		return visitor.node;
	}
	
	shared Referenceable? getReferencedDeclaration(Node node, Tree.CompilationUnit rn) {
		//NOTE: this must accept a null node, returning null!
		if (is Tree.MemberOrTypeExpression node) {
			return node.declaration;
		} 
		else if (is Tree.SimpleType node) {
			return node.declarationModel;
		} 
		else if (is Tree.ImportMemberOrType node) {
			return node.declarationModel;
		} 
		else if (is Tree.Declaration node) {
			return node.declarationModel;
		} 
		else if (is Tree.NamedArgument node) {
			Parameter? p = node.parameter;
			if (exists p) {
				return p.model;
			}
		}
		else if (is Tree.InitializerParameter node) {
			Parameter? p = node.parameterModel;
			if (exists p) {
				return p.model;
			}
		}
		else if (is Tree.MetaLiteral node) {
			return node.declaration;
		}
		else if (is Tree.SelfExpression node) {
			return node.declarationModel;
		}
		else if (is Tree.Outer node) {
			return node.declarationModel;
		}
		else if (is Tree.Return node) {
			return node.declaration;
		}
		else if (is Tree.DocLink node) {
			value qualified = CeylonList(node.qualified);
			if (!qualified.empty) {
				return qualified.last;
			}
			else {
				return node.base;
			}
		}
		else if (is Tree.ImportPath node) {
			return node.model;
		}

		return null;
	}
	
	shared void appendParameters(StringBuilder result, Tree.FunctionArgument fa, Unit unit) {
		for (pl in CeylonIterable(fa.parameterLists)) {
			result.append("(");
			variable Boolean first = true;
			
			for (p in CeylonIterable(pl.parameters)) {
				if (first) {
					first = false;
				} else {
					result.append(", ");
				}
				
				if (is Tree.InitializerParameter p) {
					if (!ModelUtil.isTypeUnknown(p.parameterModel.type)) {
						result.append(p.parameterModel.type.asSourceCodeString(unit)).append(" ");
					}
				}
				result.append(p.text); // TODO toString
			}
			result.append(")");
		}
	}
}