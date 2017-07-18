import ceylon.collection {
    HashMap,
    HashSet
}
import ceylon.interop.java {
    JavaMap,
    JavaList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.correct {
    importProposals
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    InsertEdit
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    NothingType,
    Module
}

import java.lang {
    JString=String,
    overloaded
}
import java.util {
    JMap=Map,
    JList=List
}

shared class SelectedImportsVisitor(Integer offset, Integer length) 
        extends Visitor() {
    
    value copied = HashSet<Declaration>();
    value results = HashMap<Declaration,String>();
    
    shared Map<Declaration,String> copiedReferences => results;
    
    shared JMap<Declaration,JString> copiedReferencesMap 
            => JavaMap(results.mapItems((key, item) => JString(item)));
    
    Boolean inSelection(Node node) 
            => node.startIndex exists 
            && node.endIndex exists 
            && node.startIndex.intValue() >= offset 
            && node.endIndex.intValue() <= offset+length;
    
    void addDeclaration(Declaration? dec, Tree.Identifier? id) {
        if (exists dec, exists id, dec.toplevel, 
            !dec is NothingType, !dec in copied) {
            value pname = dec.unit.\ipackage.nameAsString;
            if (!pname.empty, !pname==Module.languageModuleName) {
                results[dec] = id.text;
            }
        }
    }

    overloaded
    shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
        if (inSelection(that)) {
            addDeclaration(that.declaration, that.identifier);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.BaseType that) {
        if (inSelection(that)) {
            addDeclaration(that.declarationModel, that.identifier);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.MemberLiteral that) {
        if (inSelection(that), !that.type exists) {
            addDeclaration(that.declaration, that.identifier);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.Declaration that) {
        if (inSelection(that),
            exists dec = that.declarationModel) {
            copied.add(dec);
            results.remove(dec);
        }
        
        super.visit(that);
    }

    overloaded
    shared actual void visit(Tree.ImportMemberOrType that) {
        if (inSelection(that),
            exists dec = that.declarationModel) {
            copied.add(dec);
            results.remove(dec);
        }
    }
}

shared JList<InsertEdit> pasteImportsSet(JMap<Declaration,JString> references, 
    CommonDocument doc, Tree.CompilationUnit rootNode) 
        => JavaList(pasteImports { 
            references 
                    = map { 
                        for (r in references.entrySet()) 
                        r.key->r.\ivalue.string 
                    };
            doc = doc; 
            rootNode = rootNode; 
        });

shared List<InsertEdit> pasteImports(Map<Declaration,String> references, 
        CommonDocument doc, Tree.CompilationUnit rootNode) {
    value unit = rootNode.unit;
    value filtered = references.filterKeys((dec) 
        => unit.\ipackage!=dec.unit.\ipackage 
        && every { for (i in unit.imports) 
                    i.declaration.qualifiedNameString
                        != dec.qualifiedNameString });
    
    return importProposals.importEdits { 
        rootNode = rootNode; 
        declarations = filtered.keys; 
        aliases = filtered.items; 
        declarationBeingDeleted = null; 
        doc = doc; 
    };
}
