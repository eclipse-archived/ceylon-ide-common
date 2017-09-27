import ceylon.collection {
    MutableList
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration
}
import java.lang {
    overloaded
}

class DetectUnusedImportsVisitor(MutableList<Declaration> result)
        extends Visitor() {

    overloaded
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        for (i in that.importMemberOrTypeList.importMemberOrTypes) {
            if (exists dec = i.declarationModel) {
                result.add(dec);
            }
            
            if (exists imtl = i.importMemberOrTypeList) {
                for (j in imtl.importMemberOrTypes) {
                    if (exists dec = j.declarationModel) {
                        result.add(dec);
                    }
                }
            }
        }
    }
    
    void remove(Declaration d) => result.remove(d);
    
    Boolean isAliased(Declaration? d, Tree.Identifier? id) {
        if (!exists id) {
            return true;
        }
        return if (exists d)
            then d.name!=id.text
            else false;
    }

    overloaded
    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        super.visit(that);
        if (exists d = that.declaration,
            isAliased(d, that.identifier)) {
            remove(nodes.getAbstraction(d));
        }
    }

    overloaded
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        super.visit(that);
        if (exists d = that.declaration) {
            remove(nodes.getAbstraction(d));
        }
    }

    overloaded
    shared actual void visit(Tree.QualifiedType that) {
        super.visit(that);
        if (exists d = that.declarationModel,
            isAliased(d, that.identifier)) {
            remove(nodes.getAbstraction(d));
        }
    }

    overloaded
    shared actual void visit(Tree.BaseType that) {
        super.visit(that);
        if (exists d = that.declarationModel) {
            remove(nodes.getAbstraction(d));
        }
    }

    overloaded
    shared actual void visit(Tree.MemberLiteral that) {
        super.visit(that);
        if (!that.type exists,
            exists d = that.declaration) {
            remove(nodes.getAbstraction(d));
        }
    }
}
