import com.redhat.ceylon.ide.common.util {
    nodes,
    types
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.model.typechecker.model {
    Value,
    Type,
    ModelUtil,
    TypedDeclaration
}
import java.util {
    Collections
}

shared interface AppendMemberReferenceQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    value noTypes => Collections.emptyList<Type>();
            
    shared formal void newProposal(Data data, String desc, TextChange change,
           Integer offset, Integer length);

    shared void addAppendMemberReferenceProposals(Data data, IFile file) {
        value node = data.node;
        if (exists id = nodes.getIdentifyingNode(node),
            is Tree.StaticMemberOrTypeExpression node,
            exists t = node.typeModel) {
            
            assert (is CommonToken token = id.token);
            value required = types.getRequiredType(data.rootNode, node, token);

            if (exists requiredType = required.type) {
                value type = t.declaration;
                value dwps = type.getMatchingMemberDeclarations(node.unit, node.scope, "", 0).values();
                for (dwp in dwps) {
                    if (is Value val = dwp.declaration) {
                        value vt = val.appliedReference(t, noTypes).type;
                        if (!ModelUtil.isTypeUnknown(vt),
                            vt.isSubtypeOf(requiredType)) {
                            
                            addAppendMemberReferenceProposal(id, data, file, val, t);
                        }
                    }
                }
            }
        }
    }

    void addAppendMemberReferenceProposal(Node node, Data data, IFile file, TypedDeclaration dec, Type type) {
        value change = newTextChange("Append Member Reference", file);
        value problemOffset = node.endIndex.intValue();
        value name = dec.name;
        value desc = "Append reference to member '``name``' of type '``type``'";

        addEditToChange(change, newInsertEdit(problemOffset, "." + name));
        newProposal(data, desc, change, problemOffset, name.size + 1);
    }
}
