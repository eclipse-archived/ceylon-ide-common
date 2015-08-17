import ceylon.collection {
    HashSet,
    MutableSet
}
import ceylon.interop.java {
    CeylonIterable,
    javaString,
    createJavaStringArray
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor,
    CustomTree
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Unit,
    ModelUtil,
    Type,
    Declaration,
    Scope
}

import java.lang {
    ObjectArray,
    JString=String,
    StringBuilder
}
import java.util {
    JList=List,
    JSet=Set
}
import java.util.regex {
    Pattern
}

import org.antlr.runtime {
    Token,
    CommonToken
}

shared object nodes {

    value idPattern = Pattern.compile("(^|[A-Z])([A-Z]*)([_a-z]+)");
    value keywords = ["import", "assert",
        "alias", "class", "interface", "object", "given", "value", "assign", "void", "function", 
        "assembly", "module", "package", "of", "extends", "satisfies", "abstracts", "in", "out", 
        "return", "break", "continue", "throw", "if", "else", "switch", "case", "for", "while", 
        "try", "catch", "finally", "this", "outer", "super", "is", "exists", "nonempty", "then",
        "dynamic", "new", "let"];
    
    shared Tree.Declaration? findDeclaration(Tree.CompilationUnit cu, Node node) {
        value visitor = FindDeclarationVisitor(node);
        cu.visit(visitor);
        return visitor.declaration;
    }
    
    shared Tree.Declaration? findDeclarationWithBody(Tree.CompilationUnit cu, Node node) {
        value visitor = FindBodyContainerVisitor(node);
        cu.visit(visitor);
        return visitor.declaration;
    }
    
    shared Tree.NamedArgument? findArgument(Tree.CompilationUnit cu, Node node) {
        value visitor = FindArgumentVisitor(node);
        cu.visit(visitor);
        return visitor.declaration;
    }
    
    shared Tree.BinaryOperatorExpression? findBinaryOperator(Tree.CompilationUnit cu, Node node) {
        class FindBinaryVisitor() extends Visitor() {
            shared variable Tree.BinaryOperatorExpression? result=null;

            shared actual void visit(Tree.BinaryOperatorExpression that) {
                if (node.startIndex.intValue() >= that.startIndex.intValue() && 
                    node.stopIndex.intValue() <= that.stopIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        }
        
        FindBinaryVisitor fcv = FindBinaryVisitor();
        cu.visit(fcv);
        
        return fcv.result;
    }
    
    shared Tree.Statement? findStatement(Tree.CompilationUnit cu, Node node) {
        value fsv = FindStatementVisitor(node, false);
        cu.visit(fsv);
        return fsv.statement;
    }
    
    shared Tree.Statement? findTopLevelStatement(Tree.CompilationUnit cu, Node node) {
        value fsv = FindStatementVisitor(node, true);
        cu.visit(fsv);
        return fsv.statement;
    }

    shared Declaration? getAbstraction(Declaration? d) {
        return if (exists d, ModelUtil.isOverloadedVersion(d))
            then d.container.getDirectMember(d.name, null, false)
            else d;
    }
    
    shared Tree.Declaration? getContainer(Tree.CompilationUnit cu, Declaration dec) {
        class FindContainer() extends Visitor() {
            Scope container = dec.container;
            shared variable Tree.Declaration? result=null;

            shared actual void visit(Tree.Declaration that) {
                super.visit(that);
                if (that.declarationModel.equals(container)) {
                    result = that;
                }
            }
        }
        
        FindContainer fc = FindContainer();
        cu.visit(fc);
        return fc.result;
    }

    shared Tree.ImportMemberOrType? findImport(Tree.CompilationUnit? cu, Node? node) {
        if (is Tree.ImportMemberOrType node) {
            return node;
        }
        
        variable Declaration? declaration;
        
        if (is Tree.MemberOrTypeExpression node) {
            declaration = node.declaration;
        } else if (is Tree.SimpleType node) {
            declaration = node.declarationModel;
        } else if (is Tree.MemberLiteral node) {
            declaration = node.declaration;
        } else { 
            return null;
        }
        
        class FindImportVisitor() extends Visitor() {
            shared variable Tree.ImportMemberOrType? result=null;

            shared actual void visit(Tree.Declaration that) {}
            
            shared actual void visit(Tree.ImportMemberOrType that) {
                super.visit(that);
                Declaration? dec = that.declarationModel;
                if (exists dec, exists d = declaration, dec.equals(d)) {
                    result = that;
                }
            }
        }

        if (exists d = declaration) {
            value visitor = FindImportVisitor();
            visitor.visit(cu);
            return visitor.result;
        }
        return null;
    }

    shared Node? findNode(Node node, JList<CommonToken>? tokens, Integer startOffset, Integer endOffset = startOffset + 1) {
        FindNodeVisitor visitor = FindNodeVisitor(tokens, startOffset, endOffset);

        node.visit(visitor);

        return visitor.node;
    }

    shared Node? findScope(Tree.CompilationUnit cu, Integer startOffset, Integer endOffset) {
        value visitor = FindScopeVisitor(endOffset, endOffset);
        cu.visit(visitor);
        return visitor.scope;
    }

    shared Integer getIdentifyingStartOffset(Node? node) {
        return getNodeStartOffset(getIdentifyingNode(node));
    }

    shared Integer getIdentifyingEndOffset(Node? node) {
        return getNodeEndOffset(getIdentifyingNode(node));
    }

    shared Integer getIdentifyingLength(Node? node) {
        return getIdentifyingEndOffset(node) -
                getIdentifyingStartOffset(node);
    }

    shared Integer getNodeLength(Node? node) {
        return getNodeEndOffset(node) -
                getNodeStartOffset(node);
    }

    shared Node? getIdentifyingNode(Node? node) {
        if (is Tree.Declaration node) {
            variable Tree.Identifier? identifier = node.identifier;

            if (!exists i = identifier, !is Tree.MissingDeclaration node) {
                //TODO: whoah! this is really ugly!
                Token? tok = node.mainToken;
                if (!exists tok) {
                    return null;
                }
                else {
                    CommonToken fakeToken = CommonToken(tok);
                    identifier = Tree.Identifier(fakeToken);
                }
            }
            return identifier;
        }
        else if (is Tree.ModuleDescriptor node) {
            return node.importPath;
        }
        else if (is Tree.PackageDescriptor node) {
            return node.importPath;
        }
        else if (is Tree.Import node) {
            return node.importPath;
        }
        else if (is Tree.ImportModule node) {
            return node.importPath;
        }
        else if (is Tree.NamedArgument node) {
            Tree.Identifier? id = node.identifier;

            return if (exists t = id?.token) then id else node;
        }
        else if (is Tree.StaticMemberOrTypeExpression node) {
            return node.identifier;
        }
        else if (is CustomTree.ExtendedTypeExpression node) {
            //TODO: whoah! this is really ugly!
            return node.type.identifier;
        }
        else if (is Tree.SimpleType node) {
            return node.identifier;
        }
        else if (is Tree.ImportMemberOrType node) {
            return node.identifier;
        }
        else if (is Tree.InitializerParameter node) {
            return node.identifier;
        }
        else if (is Tree.MemberLiteral node) {
            return node.identifier;
        }
        else if (is Tree.TypeLiteral node) {
            return getIdentifyingNode(node.type);
        }
        //TODO: this would be better for navigation to refinements
        //      so I guess we should split this method into two
        //      versions :-/
        /*else if (node instanceof Tree.SpecifierStatement) {
            Tree.SpecifierStatement st = (Tree.SpecifierStatement) node;
            if (st.getRefinement()) {
                Tree.Term lhs = st.getBaseMemberExpression();
                while (lhs instanceof Tree.ParameterizedExpression) {
                    lhs = ((Tree.ParameterizedExpression) lhs).getPrimary();
                }
                if (lhs instanceof Tree.StaticMemberOrTypeExpression) {
                    return ((Tree.StaticMemberOrTypeExpression) lhs).getIdentifier();
                }
            }
            return node;
         }*/
        else {
            return node;
        }
    }

    // TODO? public static Iterator<CommonToken> getTokenIterator(List<CommonToken> tokens, IRegion region)

    shared Integer getNodeStartOffset(Node? node) {
        return node?.startIndex?.intValue() else 0;
    }

    shared Integer getNodeEndOffset(Node? node) {
        return (node?.stopIndex?.intValue() else -1) + 1;
    }

    shared Node? getReferencedNode(Referenceable? model) {
        if (exists model) {
            if (is Unit unit = model.unit) {
                // TODO!
            }
        }

        return null;
    }


    shared Referenceable? getReferencedExplicitDeclaration(Node? node, Tree.CompilationUnit? rn) {
        Referenceable? dec = getReferencedDeclaration(node);

        if (exists dec, exists node, exists unit = dec.unit, unit.equals(node.unit)) {
            FindDeclarationNodeVisitor fdv =
                    FindDeclarationNodeVisitor(dec);
            fdv.visit(rn);

            if (is Tree.Variable decNode = fdv.declarationNode) {
                if (is Tree.SyntheticVariable type = decNode.type) {
                    Tree.Term term = decNode.specifierExpression.expression.term;
                    return getReferencedExplicitDeclaration(term, rn);
                }
            }
        }
        return dec;
    }

    shared Referenceable? getReferencedDeclaration(Node? node) {
        //NOTE: this must accept a null node, returning null!
        switch (node)
        case (is Tree.MemberOrTypeExpression) {
            return node.declaration;
        }
        case (is Tree.SimpleType) {
            return node.declarationModel;
        }
        case (is Tree.ImportMemberOrType) {
            return node.declarationModel;
        }
        case (is Tree.Declaration) {
            return node.declarationModel;
        }
        case (is Tree.NamedArgument) {
            return 
                if (exists p = node.parameter) 
                then p.model 
                else null;
        }
        case (is Tree.InitializerParameter) {
            return 
                if (exists p = node.parameterModel) 
                then p.model 
                else null;
        }
        case (is Tree.MetaLiteral) {
            return node.declaration;
        }
        case (is Tree.SelfExpression) {
            return node.declarationModel;
        }
        case (is Tree.Outer) {
            return node.declarationModel;
        }
        case (is Tree.Return) {
            return node.declaration;
        }
        case (is Tree.DocLink) {
            return 
                if (exists qualified = node.qualified,
                    !qualified.empty)
                then qualified.get(qualified.size()-1)
                else node.base;
        }
        case (is Tree.ImportPath) {
            return node.model;
        }
        else {
            return null;
        }
    }

    shared void appendParameters(StringBuilder result, Tree.FunctionArgument fa, Unit unit, NodePrinter printer) {
        for (pl in CeylonIterable(fa.parameterLists)) {
            result.append("(");
            variable Boolean first = true;

            for (p in CeylonIterable(pl.parameters)) {
                if (first) {
                    first = false;
                } else {
                    result.append(", ");
                }

                if (is Tree.InitializerParameter p) {
                    if (!ModelUtil.isTypeUnknown(p.parameterModel.type)) {
                        result.append(p.parameterModel.type.asSourceCodeString(unit)).append(" ");
                    }
                }
                result.append(printer.toString(p));
            }
            result.append(")");
        }
    }

    shared OccurrenceLocation? getOccurrenceLocation(Tree.CompilationUnit cu, Node node, Integer offset) {
        value visitor = FindOccurrenceLocationVisitor(offset, node);
        cu.visit(visitor);
        return visitor.occurrence;
    }
    
    shared ObjectArray<JString> nameProposals(Node? node, Boolean unplural = false) {
        value myNode = if (is Tree.FunctionArgument node, exists e = node.expression) then e else node;
        MutableSet<String> names = HashSet<String>();
        variable Node? identifyingNode = myNode;

        if (is Tree.Expression n = identifyingNode) {
            identifyingNode = n.term;
        }
        if (is Tree.InvocationExpression n = identifyingNode) {
            identifyingNode = n.primary;
        }

        if (is Tree.QualifiedMemberOrTypeExpression qmte = identifyingNode,
                exists decl = qmte.declaration) {
            addNameProposals(names, false, decl.name);
            //TODO: propose a compound name like personName for person.name
        }
        if (is Tree.FunctionType tf = identifyingNode, is Tree.SimpleType type = tf.returnType) {
            addNameProposals(names, false, type.declarationModel.name);
        }
        if (is Tree.BaseMemberOrTypeExpression bmte = identifyingNode, unplural) {
            value name = bmte.declaration.name;
            if (name.endsWith("s") && name.size > 1) {
                addNameProposals(names, false, name.spanTo(name.size - 2));
            }
        }

        if (is Tree.SumOp n=identifyingNode) {
            names.add ("sum");
        } else if (is Tree.DifferenceOp n=identifyingNode) {
            names.add ("difference");
        } else if (is Tree.ProductOp n=identifyingNode) {
            names.add ("product");
        } else if (is Tree.QuotientOp n=identifyingNode) {
            names.add ("ratio");
        } else if (is Tree.RemainderOp n=identifyingNode) {
            names.add ("remainder");
        } else if (is Tree.UnionOp n=identifyingNode) {
            names.add ("union");
        } else if (is Tree.IntersectionOp n=identifyingNode) {
            names.add ("intersection");
        } else if (is Tree.ComplementOp n=identifyingNode) {
            names.add ("complement");
        } else if (is Tree.RangeOp n=identifyingNode) {
            names.add ("range");
        } else if (is Tree.EntryOp n=identifyingNode) {
            names.add ("entry");
        }

        if (is Tree.Term term = identifyingNode) {
            value type = term.typeModel;

            if (!ModelUtil.isTypeUnknown(type)) {
                if (!unplural, type.classOrInterface || type.typeParameter) {
                    addNameProposals(names, false, type.declaration.name);
                }
            }
            assert (exists unit = myNode?.unit);
            if (unit.isIterableType(type)) {
                Type? iter = unit.getIteratedType(type);

                if (exists iter, iter.classOrInterface || iter.typeParameter) {
                    addNameProposals(names, !unplural, iter.declaration.name);
                }
            }
        }

        if (names.empty) {
            names.add("it");
        }

        return createJavaStringArray(names);
    }

    shared void addNameProposals(MutableSet<String>|JSet<JString> names, Boolean plural, String tn) {
        value name = (tn.first?.lowercased?.string else "") + tn.spanFrom(1);
        value matcher = idPattern.matcher(javaString(name));

        while (matcher.find()) {
            value loc = matcher.start(2);
            value initial = name.span(matcher.start(1), loc - 1).lowercased;
            value subname = initial + name.spanFrom(loc + 1) + (if (plural) then "s" else "");
            value escaped = if (keywords.contains(subname))
                then "\\i" + subname
                else subname;

            if (is MutableSet<String> names) {
                names.add(escaped);
            } else {
                names.add(javaString(escaped));
            }
        }
    }
}

shared interface NodePrinter {
    shared formal String toString(Node node);
}
