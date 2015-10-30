import ceylon.collection {
    MutableList,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

class ImportProposalsVisitor(Tree.CompilationUnit cu, MutableList<Declaration> proposals,
        Declaration? chooseDeclaration(List<Declaration> decls))
        extends Visitor() {

    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        super.visit(that);
        if (!that.declaration exists) {
            value name = that.identifier.text;
            addProposal(cu, proposals, name);
        }
    }
    
    shared actual void visit(Tree.BaseType that) {
        super.visit(that);
        if (!that.declarationModel exists) {
            value name = that.identifier.text;
            addProposal(cu, proposals, name);
        }
    }
    
    void addProposal(Tree.CompilationUnit cu,
        MutableList<Declaration> proposals, String name) {
        
        for (p in proposals) {
            if (p.name.equals(name)) {
                return;
            }
        }
        
        value possibles = ArrayList<Declaration>();
        value \imodule = cu.unit.\ipackage.\imodule;
        for (p in CeylonIterable(\imodule.allVisiblePackages)) {
            if (exists d = p.getMember(name, null, false),  //TODO: pass sig
                d.toplevel, d.shared, !d.anonymous) {
                
                possibles.add(d);
            }
        }
        
        Declaration? prop;
        if (possibles.empty) {
            prop = null;
        } else if (possibles.size == 1) {
            prop = possibles.get(0);
        } else {
            prop = chooseDeclaration(possibles);
        }
        
        if (exists prop) {
            proposals.add(prop);
        }
    }
}
