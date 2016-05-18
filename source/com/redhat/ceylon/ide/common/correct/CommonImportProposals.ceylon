import ceylon.interop.java {
    JavaIterable
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    ReplaceEdit,
    CommonDocument,
    TextEdit,
    DeleteEdit,
    InsertEdit,
    platformServices,
    TextChange
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type
}

import java.util {
    JHashSet=HashSet,
    JList=List,
    JSet=Set
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import java.lang {
    JString=String,
    JIterable=Iterable
}

shared class CommonImportProposals(CommonDocument document, Tree.CompilationUnit rootNode) {
    
    value imports = JHashSet<Declaration>();
    
    object delegate satisfies ImportProposals<PhasedUnit,Nothing,CommonDocument,InsertEdit,TextEdit,TextChange> {
        
        indents = object satisfies Indents<CommonDocument> {
            getDefaultLineDelimiter(CommonDocument? doc) 
                    => document.defaultLineDelimiter;
            getLine(Node node, CommonDocument doc) 
                    => document.getLine(node);
            indentSpaces => document.indentSpaces;
            indentWithSpaces => document.indentWithSpaces;
        };
        
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
    
    shared Boolean isImported(Declaration declaration)
            => delegate.isImported(declaration, rootNode);

    shared JList<InsertEdit> importEdits(
        JIterable<Declaration> declarations,
        JIterable<JString>? aliases = null,
        Declaration? declarationBeingDeleted = null)
            => delegate.importEdits(rootNode, declarations, aliases,
                declarationBeingDeleted, document);
    
    shared void importDeclaration(Declaration declaration)
            => delegate.importDeclaration {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importType(Type? type)
            => delegate.importType {
                type = type;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importTypes({Type*} types)
            => delegate.importTypes {
                types = JavaIterable(types);
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importSignatureTypes(Declaration declaration)
            => delegate.importSignatureTypes {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
        
    shared Integer apply(TextChange change) 
            => delegate.applyImports(change, imports, rootNode, document);
    
    shared void addAll(JSet<Declaration> imports)
            => imports.addAll(imports);
}