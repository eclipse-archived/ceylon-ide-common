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
    nodes,
    escaping
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
import java.util {
    JList=List
}
import ceylon.interop.java {
    CeylonIterable
}
shared interface MemberNameCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared formal CompletionResult newMemberNameCompletionProposal(Integer offset, String prefix, String name, String unquotedName);
    
    shared void addMemberNameProposals(Integer offset, IdeComponent controller, Node node, MutableList<CompletionResult> result) {
        JInteger? startIndex2 = node.startIndex;

        if (exists upToDateAndTypechecked = controller.typecheckedRootNode) {
            object extends Visitor() {
    
                shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                    Tree.TypeArguments? tal = that.typeArguments;
                    value startIndex = if (!exists tal) then null else tal.startIndex;
                    if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                        addMemberNameProposal(offset, "", that, result, upToDateAndTypechecked);
                    }
                    super.visit(that);
                }
    
                shared actual void visit(Tree.SimpleType that) {
                    Tree.TypeArgumentList? tal = that.typeArgumentList;
                    value startIndex = if (!exists tal) then null else tal.startIndex;
                    if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                        addMemberNameProposal(offset, "", that, result, upToDateAndTypechecked);
                    }
                    super.visit(that);
                }
            }.visit(upToDateAndTypechecked);
        }
    }
    
    shared void addMemberNameProposal(Integer offset, String prefix, Node previousNode,
        MutableList<CompletionResult> result, Tree.CompilationUnit rootNode) {
        
        MutableSet<String> proposals = HashSet<String>();
        class FindCompoundTypeVisitor() extends Visitor() {
            shared variable Node result = previousNode;

            shared actual void visit(Tree.Type that) {
                if (!that.startIndex exists || !that.endIndex exists) {
                    print(that);
                    return;
                }

                if (that.startIndex.intValue() <= previousNode.startIndex.intValue()
                    && that.endIndex.intValue() >= previousNode.endIndex.intValue()) {
                    
                    result = that;
                }
            }
        }
        value fcv = FindCompoundTypeVisitor();
        fcv.visit(rootNode);
        variable Node? node = fcv.result;
        
        if (is Tree.TypeDeclaration n = node) {
            //TODO: dictionary completions?
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
        addProposalsForType(node, proposals);
        /*if (suggestedName!=null) {
            suggestedName = lower(suggestedName);
            String unquoted = prefix.startsWith("\\i")||prefix.startsWith("\\I") ?
                    prefix.substring(2) : prefix;
            if (!suggestedName.startsWith(unquoted)) {
                suggestedName = prefix + upper(suggestedName);
            }
            result.add(new CompletionProposal(offset, prefix, LOCAL_NAME,
                    suggestedName, escape(suggestedName)));
         }*/
        /*if (proposals.isEmpty()) {
            proposals.add("it");
         }*/
        for (name in proposals) {
            String unquotedPrefix = prefix.startsWith("\\i") then prefix.spanFrom(2) else prefix;
            
            if (name.startsWith(unquotedPrefix)) {
                value unquotedName = name.startsWith("\\i") then name.spanFrom(2) else name;
                result.add(newMemberNameCompletionProposal(offset, prefix, unquotedName, name));
            }
        }
    }
    
    shared void addProposalsForType(Node? node, MutableSet<String> proposals) {
        if (is Tree.SimpleType simpleType = node) {
            addProposals(proposals, simpleType.identifier, simpleType.typeModel);
        } else if (is Tree.BaseTypeExpression typeExpression = node) {
            addProposals(proposals, typeExpression.identifier, getLiteralType(typeExpression, typeExpression));
        } else if (is Tree.QualifiedTypeExpression typeExpression = node) {
            addProposals(proposals, typeExpression.identifier, getLiteralType(typeExpression, typeExpression));
        } else if (is Tree.OptionalType ot = node) {
            Tree.StaticType et = ot.definiteType;
            addProposalsForType(ot.definiteType, proposals);
            for (text in proposals) {
                value unescaped = (text.startsWith("\\i")) then text.spanFrom(2) else text;
                proposals.add("maybe``escaping.toInitialUppercase(unescaped)``");
            }
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
            proposals.add("stream");
            proposals.add("iterable");
        } else if (is Tree.TupleType tt = node) {
            value ets = tt.elementTypes;
            
            if (ets.empty) {
                proposals.add("none");
                proposals.add("empty");
            } else if (ets.size() == 1) {
                variable Tree.Type et = ets.get(0);
                if (is Tree.SequencedType st = et) {
                    et = st.type;
                    if (is Tree.SimpleType set = et) {
                        addPluralProposals(proposals, set.identifier, tt.typeModel);
                    }
                    proposals.add("sequence");
                } else {
                    addProposalsForType(et, proposals);
                    proposals.add("singleton");
                }
            } else {
                addCompoundTypeProposal(ets, proposals, "With");
                if (ets.size()==2) {
                    proposals.add("pair");
                }
                else if (ets.size()==3) {
                    proposals.add("triple");
                }
                proposals.add("tuple");
            }
        } else if (is Tree.FunctionType ft = node) {
            addProposalsForType(ft.returnType, proposals);
            proposals.add("callable");
        } else if (is Tree.UnionType ut = node) {
            addCompoundTypeProposal(ut.staticTypes, proposals, "Or");
        } else if (is Tree.IntersectionType it = node) {
            addCompoundTypeProposal(it.staticTypes, proposals, "And");
        }
    }
    
    shared void addCompoundTypeProposal(JList<out Tree.Type> ets, MutableSet<String> proposals, String join) {
        StringBuilder sb = StringBuilder();
        for (t in CeylonIterable(ets)) {
            value set = HashSet<String>();
            addProposalsForType(t, set);

            if (is String text = set.iterator().next()) {
                value _text = if (text.startsWith("\\i")) then text.spanFrom(2) else text;

                if (sb.size > 0) {
                    sb.append(join).append(escaping.toInitialUppercase(_text));
                } else {
                    sb.append(_text);
                }
            } else {
                return;
            }
        }
        
        proposals.add(sb.string);
    }


    Type getLiteralType(Node node, Tree.StaticMemberOrTypeExpression typeExpression) {
        value unit = node.unit;
        value pt = typeExpression.typeModel;
        
        return if (unit.isCallableType(pt)) then unit.getCallableReturnType(pt) else pt;
    }
    
    void addProposals(MutableSet<String> proposals, Tree.Identifier identifier, Type type) {
        nodes.addNameProposals(proposals, false, identifier.text);
        
        if (!ModelUtil.isTypeUnknown(type)) {
            if (identifier.unit.isIterableType(type)) {
                addPluralProposals(proposals, identifier, type);
            }
            if (type.isString()) {
                proposals.add("text");
                proposals.add("name");
            }
            else if (type.integer) {
                proposals.add("count");
                proposals.add("size");
                proposals.add("index");
            }
        }
    }
    
    void addPluralProposals(MutableSet<String> proposals, Tree.Identifier identifier, Type type) {
        if (!ModelUtil.isTypeUnknown(type) && !type.nothing) {
            value unit = identifier.unit;
            nodes.addNameProposals(proposals, true, unit.getIteratedType(type).declaration.getName(unit));
        }
    }
}
