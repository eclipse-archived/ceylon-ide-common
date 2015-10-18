import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

class DetectUnusedImportsVisitor(MutableList<Declaration> result)
        extends Visitor() {
    
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        for (i in CeylonIterable(that.importMemberOrTypeList.importMemberOrTypes)) {
            if (i.declarationModel exists) {
                result.add(i.declarationModel);
            }
            
            if (i.importMemberOrTypeList exists) {
                for (j in CeylonIterable(i.importMemberOrTypeList.importMemberOrTypes)) {
                    if (j.declarationModel exists) {
                        result.add(j.declarationModel);
                    }
                }
            }
        }
    }
    
    void remove(Declaration? d) {
        if (exists d) {
            result.remove(d);
        }
    }
    
    Boolean isAliased(Declaration? d, Tree.Identifier? id) {
        if (!exists id) {
            return true;
        }
        return if (exists d, !d.name.equals(id.text)) then true else false;
    }
    
    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        super.visit(that);
        value d = that.declaration;
        if (isAliased(d, that.identifier)) {
            remove(nodes.getAbstraction(d));
        }
    }
    
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        super.visit(that);
        remove(nodes.getAbstraction(that.declaration));
    }
    
    shared actual void visit(Tree.QualifiedType that) {
        super.visit(that);
        value d = that.declarationModel;
        if (isAliased(d, that.identifier)) {
            remove(nodes.getAbstraction(d));
        }
    }
    
    shared actual void visit(Tree.BaseType that) {
        super.visit(that);
        remove(nodes.getAbstraction(that.declarationModel));
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        super.visit(that);
        if (!that.type exists) {
            remove(nodes.getAbstraction(that.declaration));
        }
    }
}
