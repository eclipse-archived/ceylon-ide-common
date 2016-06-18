import ceylon.collection {
    HashMap,
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    NothingType,
    Module
}

shared class SelectedImportsVisitor(Integer offset, Integer length) 
        extends Visitor() {
    
    value copied = HashSet<Declaration>();
    value results = HashMap<Declaration,String>();
    
    shared Map<Declaration,String> copiedReferences => results;
    
    Boolean inSelection(Node node) {
        return node.startIndex.intValue()>=offset 
            && node.endIndex.intValue()<= offset+length;
    }
    
    void addDeclaration(Declaration? dec, Tree.Identifier? id) {
        if (exists dec, exists id, dec.toplevel, 
            !dec is NothingType, !dec in copied) {
            value pname = dec.unit.\ipackage.nameAsString;
            if (!pname.empty, !pname==Module.languageModuleName) {
                results.put(dec, id.text);
            }
        }
    }
    
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        if (inSelection(that)) {
            addDeclaration(that.declaration, that.identifier);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.BaseType that) {
        if (inSelection(that)) {
            addDeclaration(that.declarationModel, that.identifier);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        if (inSelection(that), !that.type exists) {
            addDeclaration(that.declaration, that.identifier);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Declaration that) {
        if (inSelection(that)) {
            value dec = that.declarationModel;
            copied.add(dec);
            results.remove(dec);
        }
        
        super.visit(that);
    }
}
