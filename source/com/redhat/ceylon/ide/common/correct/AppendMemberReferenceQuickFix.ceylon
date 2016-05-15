import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    types
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

import org.antlr.runtime {
    CommonToken
}

shared object appendMemberReferenceQuickFix {
    
    value noTypes => Collections.emptyList<Type>();
            
    shared void addAppendMemberReferenceProposals(QuickFixData data) {
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
                            
                            addAppendMemberReferenceProposal(id, data, val, t);
                        }
                    }
                }
            }
        }
    }

    void addAppendMemberReferenceProposal(Node node, QuickFixData data, 
        TypedDeclaration dec, Type type) {
        value change 
                = platformServices.createTextChange {
            name = "Append Member Reference";
            input = data.phasedUnit;
        };
        value problemOffset = node.endIndex.intValue();
        value name = dec.name;
        value desc = "Append reference to member '``name``' of type '``type``'";

        change.addEdit(InsertEdit {
            start = problemOffset;
            text = "." + name;
        });
        
        data.addQuickFix {
            desc = desc;
            change = change;
            selection = DefaultRegion {
                start = problemOffset;
                length = name.size + 1;
            };
            qualifiedNameIsPath = true;
        };
    }
}
