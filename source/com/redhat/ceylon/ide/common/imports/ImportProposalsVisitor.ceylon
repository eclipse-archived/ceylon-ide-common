import ceylon.collection {
    MutableList,
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}
import java.lang {
    overloaded
}

class ImportProposalsVisitor(Tree.CompilationUnit cu, MutableList<Declaration> proposals,
        Declaration? chooseDeclaration(List<Declaration> decls))
        extends Visitor() {

    overloaded
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        super.visit(that);
        if (!that.declaration exists) {
            value name = that.identifier.text;
            addProposal(cu, proposals, name);
        }
    }

    overloaded
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
            if (p.name==name) {
                return;
            }
        }
        
        if (exists mod = cu.unit?.\ipackage?.\imodule) { //can be null in IntelliJ for some reason!
            value possibles = ArrayList<Declaration>();
            
            for (p in mod.allVisiblePackages) {
                if (exists d = p.getMember(name, null, false),  //TODO: pass sig
                    d.toplevel, d.shared, !d.anonymous) {
                    
                    possibles.add(d);
                }
            }
            
            if (exists proposal
                    = if (possibles.size > 1)
                    then chooseDeclaration(possibles)
                    else possibles[0]) {
                proposals.add(proposal);
            }
        }
    }
}
