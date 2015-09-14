import ceylon.collection {
    MutableList,
    HashSet,
    MutableSet
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ModelUtil
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import java.lang {
    JInteger=Integer
}

shared interface MemberNameCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared formal CompletionResult newMemberNameCompletionProposal(Integer offset, String prefix, String name, String unquotedName);
    
    shared void addMemberNameProposals(Integer offset, IdeComponent cpc, Node node, MutableList<CompletionResult> result) {
        JInteger? startIndex2 = node.startIndex;
        object extends Visitor() {

            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                Tree.TypeArguments? tal = that.typeArguments;
                value startIndex = if (!exists tal) then null else tal.startIndex;
                if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                    addMemberNameProposal(offset, "", that, result);
                }
                super.visit(that);
            }

            shared actual void visit(Tree.SimpleType that) {
                Tree.TypeArgumentList? tal = that.typeArgumentList;
                value startIndex = if (!exists tal) then null else tal.startIndex;
                if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                    addMemberNameProposal(offset, "", that, result);
                }
                super.visit(that);
            }
        }.visit(cpc.rootNode);
    }
    
    shared void addMemberNameProposal(Integer offset, String prefix, variable Node? node, MutableList<CompletionResult> result) {
        MutableSet<String> proposals = HashSet<String>();
        
        if (is Tree.TypeDeclaration n = node) {
            return;
        } else if (is Tree.TypedDeclaration n = node) {
            Tree.TypedDeclaration td = n;
            Tree.Type type = td.type;
            Tree.Identifier? id = td.identifier;
            
            if (exists id) {
                node = if (offset >= id.startIndex.intValue(), offset <= id.endIndex.intValue())
                       then type
                       else null;
            } else {
                node = type;
            }
        }
        if (is Tree.SimpleType simpleType = node) {
            addProposals(proposals, simpleType.identifier, simpleType.typeModel);
        } else if (is Tree.BaseTypeExpression typeExpression = node) {
            addProposals(proposals, typeExpression.identifier, getLiteralType(typeExpression, typeExpression));
        } else if (is Tree.QualifiedTypeExpression typeExpression = node) {
            addProposals(proposals, typeExpression.identifier, getLiteralType(typeExpression, typeExpression));
        } else if (is Tree.OptionalType ot = node) {
            Tree.StaticType et = ot.definiteType;
            if (is Tree.SimpleType et) {
                addProposals(proposals, et.identifier, ot.typeModel);
            }
        } else if (is Tree.SequenceType st = node) {
            Tree.StaticType et = st.elementType;
            if (is Tree.SimpleType et) {
                addPluralProposals(proposals, et.identifier, st.typeModel);
            }
            proposals.add("sequence");
        } else if (is Tree.IterableType it = node) {
            variable Tree.Type et = it.elementType;

            if (is Tree.SequencedType st = et) {
                et = st.type;
            }
            if (is Tree.SimpleType set = et) {
                addPluralProposals(proposals, set.identifier, it.typeModel);
            }
            proposals.add("iterable");
        } else if (is Tree.TupleType tt = node) {
            value ets = tt.elementTypes;
            
            if (ets.size() == 1) {
                variable Tree.Type et = ets.get(0);
                if (is Tree.SequencedType st = et) {
                    et = st.type;
                }
                if (is Tree.SimpleType set = et) {
                    addPluralProposals(proposals, set.identifier, tt.typeModel);
                }
                proposals.add("sequence");
            }
        }
        for (String name in proposals) {
            String unquotedPrefix = if (prefix.startsWith("\\i")) then prefix.spanFrom(2) else prefix;
            if (name.startsWith(unquotedPrefix)) {
                String unquotedName = if (name.startsWith("\\i")) then name.spanFrom(2) else name;
                result.add(newMemberNameCompletionProposal(offset, prefix, name, unquotedName));
            }
        }
    }
    
    Type getLiteralType(Node node, Tree.StaticMemberOrTypeExpression typeExpression) {
        value unit = node.unit;
        value pt = typeExpression.typeModel;
        
        return if (unit.isCallableType(pt)) then unit.getCallableReturnType(pt) else pt;
    }
    
    void addProposals(MutableSet<String> proposals, Tree.Identifier identifier, Type type) {
        nodes.addNameProposals(proposals, false, identifier.text);
        
        if (!ModelUtil.isTypeUnknown(type) && identifier.unit.isIterableType(type)) {
            addPluralProposals(proposals, identifier, type);
        }
    }
    
    void addPluralProposals(MutableSet<String> proposals, Tree.Identifier identifier, Type type) {
        if (!ModelUtil.isTypeUnknown(type) && !type.nothing) {
            value unit = identifier.unit;
            nodes.addNameProposals(proposals, true, unit.getIteratedType(type).declaration.getName(unit));
        }
    }
}
