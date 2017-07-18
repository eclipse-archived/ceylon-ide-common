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

import java.util {
    JList=List
}
import java.lang {
    overloaded
}

shared interface MemberNameCompletion {
        
    shared void addMemberNameProposals(Integer offset, CompletionContext ctx, Node node) {
        value startIndex2 = node.startIndex;

        if (exists upToDateAndTypechecked = ctx.typecheckedRootNode) {
            object extends Visitor() {

                overloaded
                shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                    if (exists tal = that.typeArguments, 
                        exists startIndex = tal.startIndex,
                        exists startIndex2, 
                        startIndex.intValue() == startIndex2.intValue()) {
                        
                        addMemberNameProposalsForType {
                            ctx = ctx;
                            offset = offset;
                            prefix = "";
                            node = that;
                        };
                    }
                    super.visit(that);
                }

                overloaded
                shared actual void visit(Tree.SimpleType that) {
                    if (exists tal = that.typeArgumentList, 
                        exists startIndex = tal.startIndex,
                        exists startIndex2, 
                        startIndex.intValue() == startIndex2.intValue()) {
                        
                        addMemberNameProposalsForType {
                            ctx = ctx;
                            offset = offset;
                            prefix = "";
                            node = compoundType(that, upToDateAndTypechecked);
                        };
                    }
                    super.visit(that);
                }
            }.visit(upToDateAndTypechecked);
        }
    }

    Tree.Type compoundType(Tree.SimpleType typeNode, Tree.CompilationUnit rootNode) {
        object findCompoundTypeVisitor extends Visitor() {
            shared variable Tree.Type result = typeNode;

            shared actual void visit(Tree.Type that) {
                if (exists thatStart = that.startIndex,
                    exists prevStart = typeNode.startIndex,
                    exists thatEnd = that.endIndex,
                    exists prevEnd = typeNode.endIndex,
                    thatStart.intValue() <= prevStart.intValue() &&
                    thatEnd.intValue() >= prevEnd.intValue()) {
                    result = that;
                }
            }
        }
        findCompoundTypeVisitor.visit(rootNode);
        return findCompoundTypeVisitor.result;
    }

    shared void addMemberNameProposalsForType(CompletionContext ctx,
            Integer offset, String prefix,
            Tree.Type|Tree.StaticMemberOrTypeExpression node) {

        value proposals = HashSet<String>();

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
            String unquotedPrefix
                    = prefix.startsWith("\\i")
                    then prefix[2...]
                    else prefix;
            if (name.startsWith(unquotedPrefix)) {
                value unquotedName
                        = name.startsWith("\\i")
                        then name[2...]
                        else name;
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

    shared void addMemberNameProposal(CompletionContext ctx,
            Integer offset, String prefix,
            Tree.TypedDeclaration previousNode,
            Tree.CompilationUnit rootNode) {

        Tree.Type node;
        switch (previousNode)
        case (is Tree.TypedDeclaration) {
            value type = previousNode.type;
            if (exists id = previousNode.identifier) {
                if (exists start = id.startIndex,
                    exists end = id.endIndex,
                    start.intValue() <= offset <= end.intValue()) {
                    node = type;
                }
                else {
                    return;
                }
            } else {
                node = type;
            }
        }

        addMemberNameProposalsForType {
            prefix = prefix;
            node = node;
            ctx = ctx;
            offset = offset;
        };
    }
    
    void addProposalsForType(
            Tree.Type|Tree.StaticMemberOrTypeExpression node,
            MutableSet<String> proposals) {
        switch (node)
        case (is Tree.SimpleType) {
            if (exists model = node.typeModel) {
                addProposals {
                    proposals = proposals;
                    identifier = node.identifier;
                    type = model;
                };
            }
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
                addPluralProposals {
                    proposals = proposals;
                    identifier = et.identifier;
                    type = node.typeModel;
                };
            }
            proposals.add("sequence");
        }
        case (is Tree.IterableType) {
            if (is Tree.SequencedType st = node.elementType,
                is Tree.SimpleType et = st.type) {
                addPluralProposals {
                    proposals = proposals;
                    identifier = et.identifier;
                    type = node.typeModel;
                };
            }
            proposals.add("stream");
            proposals.add("iterable");
        }
        case (is Tree.TupleType) {
            value ets = node.elementTypes;
            if (ets.empty) {
                proposals.add("none");
                proposals.add("empty");
            }
            else if (ets.size() == 1) {
                value first = ets.get(0);
                if (is Tree.SequencedType first) {
                    if (is Tree.SimpleType set = first.type) {
                        addPluralProposals {
                            proposals = proposals;
                            identifier = set.identifier;
                            type = node.typeModel;
                        };
                    }
                    proposals.add("sequence");
                } else {
                    addProposalsForType(first, proposals);
                    proposals.add("singleton");
                }
            }
            else {
                addCompoundTypeProposal {
                    ets = ets;
                    proposals = proposals;
                    join = "With";
                };
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
            addProposalsForType {
                node = node.returnType;
                proposals = proposals;
            };
            proposals.add("callable");
        }
        case (is Tree.UnionType) {
            addCompoundTypeProposal {
                ets = node.staticTypes;
                proposals = proposals;
                join = "Or";
            };
        }
        case (is Tree.IntersectionType) {
            addCompoundTypeProposal {
                ets = node.staticTypes;
                proposals = proposals;
                join = "And";
            };
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
                value withoutEscape =
                        if (text.startsWith("\\i"))
                        then text[2...] else text;
                if (sb.empty) {
                    sb.append(withoutEscape);
                } else {
                    sb.append(join)
                      .append(escaping.toInitialUppercase(withoutEscape));
                }
            } else {
                return;
            }
        }
        
        proposals.add(sb.string);
    }


    Type getLiteralType(Node node,
            Tree.StaticMemberOrTypeExpression typeExpression) {
        value unit = node.unit;
        value pt = typeExpression.typeModel;
        return unit.isCallableType(pt)
            then unit.getCallableReturnType(pt)
            else pt;
    }
    
    void addProposals(MutableSet<String> proposals,
            Tree.Identifier identifier, Type type) {
        nodes.addNameProposals {
            names = proposals;
            plural = false;
            name = identifier.text;
        };
        
        if (!ModelUtil.isTypeUnknown(type)) {
            addPluralProposals {
                proposals = proposals;
                identifier = identifier;
                type = type;
            };
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
    
    void addPluralProposals(MutableSet<String> proposals,
            Tree.Identifier identifier, Type type) {
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
            nodes.addNameProposals {
                names = proposals;
                plural = true;
                name = it.declaration.getName(unit);
            };
        }
    }
}
