import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.util {
    NormalizedLevenshtein
}
import com.redhat.ceylon.ide.common.completion {
    isLocation
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    OccurrenceLocation
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Module,
    NamedArgumentList
}

import java.util {
    Collections
}
shared interface ChangeReferenceQuickFix<IFile,Project,Document,InsertEdit,TextEdit,TextChange,Data,Region,CompletionResult>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & AbstractQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
   
    shared formal void newChangeReferenceProposal(Data data, String desc, TextChange change, Region selection);

    void addChangeReferenceProposal(Data data, IFile file, String brokenName, Declaration dec) {
        value change = newTextChange("Change Reference", file);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        variable value pkg = "";
        value problemOffset = data.problemOffset;
        variable value importsLength = 0;
        
        if (dec.toplevel, !importProposals.isImported(dec, data.rootNode), isInPackage(data.rootNode, dec)) {
            value pn = dec.container.qualifiedNameString;
            pkg = " in '" + pn + "'";
            if (!pn.empty, !pn.equals(Module.\iLANGUAGE_MODULE_NAME),
                exists node = nodes.findNode(data.rootNode, null, problemOffset)) {
                
                value ol = nodes.getOccurrenceLocation(data.rootNode, node, problemOffset);
                if (!isLocation(ol, OccurrenceLocation.\iIMPORT)) {
                    value ies = importProposals.importEdits(data.rootNode, Collections.singleton(dec), null, null, doc);
                    for (ie in ies) {
                        importsLength += getInsertedText(ie).size;
                        addEditToChange(change, ie);
                    }
                }
            }
        }
        
        //Note: don't use problem.getLength() because it's wrong from the problem list
        addEditToChange(change, newReplaceEdit(problemOffset, brokenName.size, dec.name));
        
        value desc = "Change reference to '" + dec.name + "'" + pkg;
        value selection = newRegion(problemOffset + importsLength, dec.name.size);
        newChangeReferenceProposal(data, desc, change, selection);
    }
    
    Boolean isInPackage(Tree.CompilationUnit cu, Declaration dec) {
        return !dec.unit.\ipackage.equals(cu.unit.\ipackage);
    }

    shared void addChangeReferenceProposals(Data data, IFile file) {
        if (exists id = nodes.getIdentifyingNode(data.node)) {
            if (exists brokenName = id.text, !brokenName.empty) {
                value scope = data.node.scope; //for declaration-style named args
                value dwps = completionManager.getProposals(data.node, scope, "", false, data.rootNode, null).values();
                for (dwp in dwps) {
                    processProposal(data, file, brokenName, dwp.declaration);
                }
            }
        }
    }
    
    shared void addChangeArgumentReferenceProposals(Data data, IFile file) {
        assert(exists id = nodes.getIdentifyingNode(data.node));
        String? brokenName = id.text;
        
        if (exists brokenName, !brokenName.empty) {
            if (is Tree.NamedArgument node = data.node) {
                variable value scope = node.scope;
                if (!(scope is NamedArgumentList)) {
                    scope = scope.scope; //for declaration-style named args
                }
                assert(is NamedArgumentList namedArgumentList = scope);
                if (exists parameterList = namedArgumentList.parameterList) {
                    for (parameter in parameterList.parameters) {
                        if (exists declaration = parameter.model) {
                            processProposal(data, file, brokenName, declaration);
                        }
                    }
                }
            }
        }
    }

    void processProposal(Data data, IFile file, String brokenName, Declaration declaration) {
        value name = declaration.name;
        if (!brokenName.equals(name)) {
            value nuc = name.first?.uppercase else false;
            value bnuc = brokenName.first?.uppercase else false;
            if (nuc == bnuc) {
                value similarity = distance.similarity(brokenName, name);
                //TODO: would it be better to just sort by distance, 
                //      and then select the 3 closest possibilities?
                if (similarity > 0.6) {
                    addChangeReferenceProposal(data, file, brokenName, declaration);
                }
            }
        }
    }


}

NormalizedLevenshtein distance = NormalizedLevenshtein();