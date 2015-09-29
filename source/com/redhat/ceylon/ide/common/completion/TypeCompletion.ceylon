import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ModelUtil,
    TypeDeclaration,
    Declaration
}

import java.lang {
    Character
}
import java.util {
    HashSet
}

shared interface TypeCompletion<CompletionResult,Document> {
    
    shared formal CompletionResult newTypeProposal(Integer offset, Type? type,
            String text, String desc, Tree.CompilationUnit rootNode);
    
    shared CompletionResult[] getTypeProposals(Document document, Integer offset, Integer length,
        Type infType, Tree.CompilationUnit rootNode, String? kind) {
        
        value td = infType.declaration;
        value supertypes = if (ModelUtil.isTypeUnknown(infType) || infType.typeConstructor)
                           then empty else CeylonList(td.supertypeDeclarations);
        variable value size = supertypes.size;
        
        if (exists kind) {
            size++;
        }
        if (infType.typeConstructor || infType.union || infType.intersection) {
            size++;
        }
        
        value proposals = ArrayList<CompletionResult>(size);
        variable value i = 0;
        if (exists kind) {
            proposals.insert(i++, newTypeProposal(offset, null, kind, kind, rootNode));
        }
        value unit = rootNode.unit;
        if (infType.typeConstructor || infType.union || infType.intersection) {
            proposals.insert(i++, newTypeProposal(offset, infType, infType.asSourceCodeString(unit),
                infType.asString(unit), rootNode));
        }
        
        supertypes.sort((TypeDeclaration x, TypeDeclaration y) {
            if (x.inherits(y)) {
                return larger;
            }
            if (y.inherits(x)) {
                return smaller;
            }
            return y.name.compare(x.name);
        });
        
        variable value j = supertypes.size - 1;
        while (j >= 0) {
            value type = infType.getSupertype(supertypes.get(j));
            proposals.insert(i++, newTypeProposal(offset, type, type.asSourceCodeString(unit), type.asString(unit), rootNode));
            j--;
        }
        
        return proposals.sequence();
    }
}


shared abstract class TypeProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region>
        (Integer offset, Type? type, String text, String desc, Tree.CompilationUnit rootNode)
        extends AbstractCompletionProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region>
        (offset, "", desc, text)
        given InsertEdit satisfies TextEdit {
    
    shared Region applyChange(TextChange change, Document document) {
        initMultiEditChange(change);
        value decs = HashSet<Declaration>();
        if (exists type) {
            importProposals.importType(decs, type, rootNode);
        }
        
        value il = importProposals.applyImports(change, decs, rootNode, document);
        addEditToChange(change, newReplaceEdit(offset, getCurrentLength(document), text));

        return newRegion(offset+il, text.size);
    }
    
    Integer getCurrentLength(Document document) {
        variable value length = 0;
        variable value i = offset;
        while (i < getDocLength(document)) {
            if (Character.isWhitespace(getDocChar(document, i).charValue())) {
                break;
            }
            length++;
            i++;
        }
        return length;
    }


}