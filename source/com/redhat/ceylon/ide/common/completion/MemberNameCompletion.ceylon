import ceylon.collection {
    HashSet,
    MutableSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ModelUtil
}

import java.lang {
    JInteger=Integer
}
import java.util {
    JList=List
}

shared interface MemberNameCompletion {
        
    shared void addMemberNameProposals(Integer offset, CompletionContext ctx, Node node) {
        JInteger? startIndex2 = node.startIndex;

        if (exists upToDateAndTypechecked = ctx.typecheckedRootNode) {
            object extends Visitor() {
    
                shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                    if (exists tal = that.typeArguments, 
                        exists startIndex = tal.startIndex,
                        exists startIndex2, 
                        startIndex.intValue() == startIndex2.intValue()) {
                        
                        addMemberNameProposal {
                            ctx = ctx;
                            offset = offset;
                            prefix = "";
                            previousNode = that;
                            rootNode = upToDateAndTypechecked;
                        };
                    }
                    super.visit(that);
                }
    
                shared actual void visit(Tree.SimpleType that) {
                    if (exists tal = that.typeArgumentList, 
                        exists startIndex = tal.startIndex,
                        exists startIndex2, 
                        startIndex.intValue() == startIndex2.intValue()) {
                        
                        addMemberNameProposal {
                            ctx = ctx;
                            offset = offset;
                            prefix = "";
                            previousNode = that;
                            rootNode = upToDateAndTypechecked;
                        };
                    }
                    super.visit(that);
                }
            }.visit(upToDateAndTypechecked);
        }
    }
    
    shared void addMemberNameProposal(CompletionContext ctx, Integer offset,
        String prefix, Node previousNode, Tree.CompilationUnit rootNode) {
        
        value proposals = HashSet<String>();
        class FindCompoundTypeVisitor() extends Visitor() {
            shared variable Node result = previousNode;

            shared actual void visit(Tree.Type that) {
                if (exists thatStart = that.startIndex,
                    exists prevStart = previousNode.startIndex,
                    exists thatEnd = that.endIndex,
                    exists prevEnd = previousNode.endIndex,
                    thatStart.intValue() <= prevStart.intValue() && 
                    thatEnd.intValue() >= prevEnd.intValue()) {
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
                node =
                        if (exists start = id.startIndex,
                            exists end = id.endIndex,
                            start.intValue() <= offset <= end.intValue())
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
            String unquotedPrefix = prefix.startsWith("\\i") then prefix[2...] else prefix;
            if (name.startsWith(unquotedPrefix)) {
                value unquotedName = name.startsWith("\\i") then name[2...] else name;
                platformServices.completion.addProposal {
                    ctx = ctx;
                    offset = offset;
                    prefix = prefix;
                    description = unquotedName;
                    text = name;
                    icon = Icons.localAttribute;
                };
            }
        }
    }
    
    void addProposalsForType(Node? node, MutableSet<String> proposals) {
        switch (node)
        case (is Tree.SimpleType) {
            addProposals(proposals, node.identifier, node.typeModel);
        }
        case (is Tree.BaseTypeExpression) {
            addProposals(proposals, node.identifier,
                getLiteralType(node, node));
        }
        case (is Tree.QualifiedTypeExpression) {
            addProposals(proposals, node.identifier,
                getLiteralType(node, node));
        }
        case (is Tree.OptionalType) {
            addProposalsForType(node.definiteType, proposals);
            for (text in proposals.clone()) {
                value unescaped =
                        text.startsWith("\\i")
                        then text[2...] else text;
                proposals.add("maybe" +
                    escaping.toInitialUppercase(unescaped));
            }
        }
        case (is Tree.SequenceType) {
            Tree.StaticType et = node.elementType;
            if (is Tree.SimpleType et) {
                addPluralProposals(proposals, et.identifier, node.typeModel);
            }
            proposals.add("sequence");
        }
        case (is Tree.IterableType) {
            if (is Tree.SequencedType st = node.elementType,
                is Tree.SimpleType et = st.type) {
                addPluralProposals(proposals, et.identifier, node.typeModel);
            }
            proposals.add("stream");
            proposals.add("iterable");
        }
        case (is Tree.TupleType) {
            value ets = node.elementTypes;
            if (ets.empty) {
                proposals.add("none");
                proposals.add("empty");
            } else if (ets.size() == 1) {
                value first = ets.get(0);
                if (is Tree.SequencedType first) {
                    if (is Tree.SimpleType set = first.type) {
                        addPluralProposals(proposals, set.identifier, node.typeModel);
                    }
                    proposals.add("sequence");
                } else {
                    addProposalsForType(first, proposals);
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
        }
        case (is Tree.FunctionType) {
            addProposalsForType(node.returnType, proposals);
            proposals.add("callable");
        }
        case (is Tree.UnionType) {
            addCompoundTypeProposal(node.staticTypes, proposals, "Or");
        }
        case (is Tree.IntersectionType) {
            addCompoundTypeProposal(node.staticTypes, proposals, "And");
        }
        else {}
    }
    
    void addCompoundTypeProposal(JList<out Tree.Type> ets, 
        MutableSet<String> proposals, String join) {
        
        value sb = StringBuilder();
        for (t in ets) {
            value set = HashSet<String>();
            addProposalsForType(t, set);
            if (!is Finished text = set.iterator().next()) {
                value _text =
                        if (text.startsWith("\\i"))
                        then text[2...] else text;
                if (sb.empty) {
                    sb.append(_text);
                } else {
                    sb.append(join)
                      .append(escaping.toInitialUppercase(_text));
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
            addPluralProposals(proposals, identifier, type);
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
            Type it;
            if (unit.isIterableType(type)) {
                it = unit.getIteratedType(type);
            }
            else if (unit.isJavaIterableType(type)) {
                it = unit.getJavaIteratedType(type);
            }
            else if (unit.isJavaArrayType(type)) {
                it = unit.getJavaArrayElementType(type);
            }
            else {
                return;
            }
            nodes.addNameProposals(proposals, true, it.declaration.getName(unit));
        }
    }
}
