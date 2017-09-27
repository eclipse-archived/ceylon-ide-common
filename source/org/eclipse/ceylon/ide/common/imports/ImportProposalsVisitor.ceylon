import ceylon.collection {
    MutableList,
    ArrayList
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration
}
import java.lang {
    overloaded
}

class ImportProposalsVisitor(Node scope, proposals,
        chooseDeclaration)
        extends Visitor() {

    MutableList<Declaration> proposals;
    Declaration? chooseDeclaration(List<Declaration> decls);

    overloaded
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        super.visit(that);
        if (!that.declaration exists) {
            value name = that.identifier.text;
            addProposal(proposals, name);
        }
    }

    overloaded
    shared actual void visit(Tree.BaseType that) {
        super.visit(that);
        if (!that.declarationModel exists) {
            value name = that.identifier.text;
            addProposal(proposals, name);
        }
    }
    
    void addProposal(MutableList<Declaration> proposals, String name) {
        
        for (p in proposals) {
            if (p.name==name) {
                return;
            }
        }
        
        if (exists mod = scope.unit?.\ipackage?.\imodule) { //can be null in IntelliJ for some reason!
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
