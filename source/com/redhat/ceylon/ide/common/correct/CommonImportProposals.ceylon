import java.util {
    JHashSet=HashSet
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import ceylon.interop.java {
    JavaIterable
}
import com.redhat.ceylon.ide.common.platform {
    ReplaceEdit,
    commonIndents,
    CommonDocument,
    TextEdit,
    DeleteEdit,
    InsertEdit,
    platformServices,
    TextChange
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type
}

shared class CommonImportProposals(CommonDocument document, Tree.CompilationUnit rootNode) {
    
    value imports = JHashSet<Declaration>();
    
    shared void addImportedDeclaration(Declaration declaration)
            => delegate.importDeclaration {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void addImportedType(Type type)
            => delegate.importType {
                type = type;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void addImportedTypes({Type*} types)
            => delegate.importTypes {
                types = JavaIterable(types);
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void addImportedSignatureTypes(Declaration declaration)
            => delegate.importSignatureTypes {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
        
    shared Integer applyAddedImports(TextChange change) 
            => delegate.applyImports(change, imports, rootNode, document);
    
    object delegate satisfies ImportProposals<PhasedUnit,Nothing,CommonDocument,InsertEdit,TextEdit,TextChange> {
        
        addEditToChange(TextChange change, TextEdit edit) 
                => change.addEdit(edit);
        
        createImportChange(PhasedUnit file) 
                => platformServices.createTextChange("", file);
        
        getDocContent(CommonDocument doc, Integer start, Integer length) 
                => doc.getText(start, length);
        
        getDocumentForChange(TextChange change) => change.document;
        
        getInsertedText(TextEdit edit) 
                => if (is InsertEdit edit) then edit.text else "";
        
        getLineContent(CommonDocument doc, Integer line) 
                => doc.getLineContent(line);
        
        getLineOfOffset(CommonDocument doc, Integer offset) 
                => doc.getLineOfOffset(offset);
        
        getLineStartOffset(CommonDocument doc, Integer line) 
                => doc.getLineStartOffset(line);
        
        hasChildren(TextChange change) => change.hasEdits;
        
        indents => commonIndents;
        
        initMultiEditChange(TextChange change) 
                => change.initMultiEdit();
        
        newDeleteEdit(Integer start, Integer length) 
                => DeleteEdit(start, length);
        
        newImportProposal(String description, TextChange correctionChange) 
                => nothing;
        
        newInsertEdit(Integer position, String text)
                => InsertEdit(position, text);
        
        newReplaceEdit(Integer start, Integer length, String text)
                => ReplaceEdit(start, length, text);
        
    }

}