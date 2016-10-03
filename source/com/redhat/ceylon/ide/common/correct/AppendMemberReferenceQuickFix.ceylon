import ceylon.interop.java {
    javaString
}

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
        value node
                = switch (node = data.node) 
                case (is Tree.SpecifierExpression) 
                    node.expression.term
                //case (is Tree.Expression) 
                //    node.term
                else node;
        if (is Tree.Primary node, //TODO: if it's not a primary, just add parens!
            exists type = node.typeModel) {
            value token = 
                    if (is Tree.StaticMemberOrTypeExpression node, 
                        is CommonToken token = node.identifier.token)
                    then token else null;

            if (exists requiredType 
                    = types.getRequiredType(data.rootNode, node, token)
                          .type) {
                value proposals 
                        = type.declaration
                              .getMatchingMemberDeclarations(
                                    node.unit, node.scope, "", 0, null);
                for (dwp in proposals.values()) {
                    if (is Value val = dwp.declaration,
                        !javaString(dwp.name) in val.aliases) {
                        value vt = val.appliedReference(type, noTypes).type;
                        if (!ModelUtil.isTypeUnknown(vt) 
                            && vt.isSubtypeOf(requiredType)) {
                            addAppendMemberReferenceProposal {
                                node = node;
                                data = data;
                                dec = val;
                                type = type;
                            };
                        }
                    }
                }
            }
        }
    }

    void addAppendMemberReferenceProposal(Node node, QuickFixData data, 
        TypedDeclaration dec, Type type) {
        value change 
                = platformServices.document.createTextChange {
            name = "Append Member Reference";
            input = data.phasedUnit;
        };
        
        change.addEdit(InsertEdit {
            start = node.endIndex.intValue();
            text = "." + dec.name;
        });
        
        data.addQuickFix {
            description = "Append reference to member '``dec.name``' of type '``type.asString(node.unit)``'";
            change = change;
            selection = DefaultRegion {
                start = node.endIndex.intValue();
                length = dec.name.size + 1;
            };
        };
    }
}
