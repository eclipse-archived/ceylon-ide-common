import ceylon.interop.java {
    JavaIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    InsertEdit,
    TextChange
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type
}

import java.lang {
    JString=String,
    JIterable=Iterable
}
import java.util {
    JHashSet=HashSet
}

shared class CommonImportProposals(CommonDocument document, Tree.CompilationUnit rootNode) {
    
    value imports = JHashSet<Declaration>();
    
    shared Boolean isImported(Declaration declaration)
            => importProposals.isImported(declaration, rootNode);

    shared List<InsertEdit> importEdits(
        JIterable<Declaration> declarations,
        JIterable<JString>? aliases = null,
        Declaration? declarationBeingDeleted = null)
            => importProposals.importEdits {
                rootNode = rootNode;
                declarations = declarations;
                aliases = aliases;
                declarationBeingDeleted = declarationBeingDeleted;
                doc = document;
            };
    
    shared void importDeclaration(Declaration declaration)
            => importProposals.importDeclaration {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importType(Type? type)
            => importProposals.importType {
                type = type;
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importTypes({Type*} types)
            => importProposals.importTypes {
                types = JavaIterable(types);
                declarations = imports;
                rootNode = rootNode;
            };
    
    shared void importSignatureTypes(Declaration declaration)
            => importProposals.importSignatureTypes {
                declaration = declaration;
                declarations = imports;
                rootNode = rootNode;
            };
        
    shared Integer apply(TextChange change) 
            => importProposals.applyImports(change, imports, rootNode, document);
}