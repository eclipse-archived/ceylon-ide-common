import ceylon.collection {
    HashSet,
    MutableSet
}
import ceylon.interop.java {
    javaString,
    createJavaStringArray
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor,
    CustomTree,
    TreeUtil
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit,
    CeylonBinaryUnit,
    BaseIdeModule
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Unit,
    ModelUtil,
    Type,
    Declaration,
    Scope,
    FunctionOrValue,
    Function,
    Parameter,
    Class,
    ParameterList
}

import java.lang {
    ObjectArray,
    JString=String,
    StringBuilder
}
import java.util {
    JList=List,
    JSet=Set,
    JIterator=Iterator,
    Collections
}
import java.util.regex {
    Pattern
}

import org.antlr.runtime {
    CommonToken
}

shared object nodes {

    value idPattern = Pattern.compile("(^[a-z]|[A-Z])([A-Z]*)([_a-z]+)");
    value keywords = ["import", "assert",
        "alias", "class", "interface", "object", "given", "value", "assign", "void", "function",
        "assembly", "module", "package", "of", "extends", "satisfies", "abstracts", "in", "out",
        "return", "break", "continue", "throw", "if", "else", "switch", "case", "for", "while",
        "try", "catch", "finally", "this", "outer", "super", "is", "exists", "nonempty", "then",
        "dynamic", "new", "let"];
    value wordPattern = Pattern.compile("\\p{Alpha}+");

    shared Tree.Declaration? findDeclaration(Tree.CompilationUnit cu, Node node) {
        value visitor = FindDeclarationVisitor(node);
        cu.visit(visitor);
        return visitor.declaration;
    }

    shared Node? findReferencedNode(Tree.CompilationUnit cu, Referenceable model) {
        value visitor = FindReferencedNodeVisitor(model);
        cu.visit(visitor);
        return visitor.declarationNode;
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
    
    [Tree.InvocationExpression?, Tree.SequencedArgument?, Tree.NamedArgument|Tree.PositionalArgument?]? findArgumentContext(Tree.CompilationUnit cu, Node node) {
        value visitor = FindArgumentContextVisitor(node);
        cu.visit(visitor);
        return visitor.context;
    }

    shared Tree.OperatorExpression? findOperator(Tree.CompilationUnit cu, Node node) {
        variable Tree.OperatorExpression? result=null;
        cu.visit(object extends Visitor() {
            shared actual void visit(Tree.OperatorExpression that) {
                if (node.startIndex.intValue() >= that.startIndex.intValue() &&
                    node.endIndex.intValue() <= that.endIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        });
        return result;
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

    shared Declaration? getAbstraction(Declaration? d)
        => if (exists d, ModelUtil.isOverloadedVersion(d))
            then d.container.getDirectMember(d.name, null, false)
            else d;

    shared Tree.Declaration? getContainer(Tree.CompilationUnit cu, Declaration dec) {
        variable Tree.Declaration? result=null;
        cu.visit(object extends Visitor() {
            Scope container = dec.container;
            shared actual void visit(Tree.Declaration that) {
                super.visit(that);
                if (that.declarationModel.equals(container)) {
                    result = that;
                }
            }
        });
        return result;
    }

    shared Tree.ImportMemberOrType? findImport(Tree.CompilationUnit cu, Node node) {
        Declaration? declaration;
        switch (node)
        case (is Tree.ImportMemberOrType) {
            return node;
        }
        case (is Tree.MemberOrTypeExpression) {
            declaration = node.declaration;
        } 
        case (is Tree.SimpleType) {
            declaration = node.declarationModel;
        } 
        case (is Tree.MemberLiteral) {
            declaration = node.declaration;
        }
        else {
            return null;
        }

        if (exists d = declaration) {
            variable Tree.ImportMemberOrType? result=null;
            object extends Visitor() {
                shared actual void visit(Tree.Declaration that) {}
                shared actual void visit(Tree.ImportMemberOrType that) {
                    super.visit(that);
                    if (exists dec = that.declarationModel, 
                        exists d = declaration, dec==d) {
                        result = that;
                    }
                }
            }.visit(cu);
            return result;
        }
        return null;
    }

    "Finds the most specific node within [[node]] for which 
     the selection given by [[startOffset]] and [[endOffset]]
     is contained within the node plus surrounding whitespace.
     
     [[startOffset]] is the index of the first selected character,
     and [[endOffset]] is the index of the first character past 
     the selection. Thus, the length of the selection is 
     `endOffset - startOffset`."
    shared Node? findNode(Node node, JList<CommonToken>? tokens, 
        Integer startOffset, Integer endOffset = startOffset) {
        FindNodeVisitor visitor = FindNodeVisitor(tokens, startOffset, endOffset);
        node.visit(visitor);
        return visitor.node;
    }

    shared Node? findScope(Tree.CompilationUnit cu, 
        Integer startOffset, Integer endOffset) {
        value visitor = FindScopeVisitor(endOffset, endOffset);
        cu.visit(visitor);
        return visitor.scope;
    }

    shared Integer getIdentifyingStartOffset(Node? node) 
            => getNodeStartOffset(getIdentifyingNode(node));

    shared Integer getIdentifyingEndOffset(Node? node) 
            => getNodeEndOffset(getIdentifyingNode(node));

    shared Integer getIdentifyingLength(Node? node) 
            => getIdentifyingEndOffset(node) -
                getIdentifyingStartOffset(node);

    shared Integer getNodeLength(Node? node) 
            => getNodeEndOffset(node) -
                getNodeStartOffset(node);

    shared Node? getIdentifyingNode(Node? node) {
        switch (node)
        case (is Tree.Declaration) {
            if (exists id = node.identifier) {
                return id;
            }
            else if (node is Tree.MissingDeclaration) {
                return null;
            }
            else {
                //TODO: whoah! this is really ugly!
                return 
                    if (exists tok = node.mainToken) 
                    then Tree.Identifier(CommonToken(tok)) 
                    else null;
            }
        }
        case (is Tree.ModuleDescriptor) {
            if (exists ip = node.importPath) {
                return ip;
            }
        }
        case (is Tree.PackageDescriptor) {
            if (exists ip = node.importPath) {
                return ip;
            }
        }
        case (is Tree.Import) {
            if (exists ip = node.importPath) {
                return ip;
            }
        }
        case (is Tree.ImportModule) {
            if (exists ip = node.importPath) {
                return ip;
            }
            else if (exists p = node.quotedLiteral) {
                return p;
            }
        }
        case (is Tree.NamedArgument) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is Tree.StaticMemberOrTypeExpression) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is CustomTree.ExtendedTypeExpression) {
            //TODO: whoah! this is really ugly!
            return node.type.identifier;
        }
        case (is Tree.SimpleType) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is Tree.ImportMemberOrType) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is Tree.InitializerParameter) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is Tree.MemberLiteral) {
            if (exists id = node.identifier) {
                return id;
            }
        }
        case (is Tree.TypeLiteral) {
            return getIdentifyingNode(node.type);
        }
        else {}
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
        return node;
    }

    shared JIterator<CommonToken>? getTokenIterator(JList<CommonToken>? tokens, DefaultRegion region) {
        value regionOffset = region.start;
        value regionLength = region.length;
        if (regionLength <= 0) {
            return Collections.emptyList<CommonToken>().iterator();
        }
        value regionEnd = regionOffset + regionLength - 1;
        if (exists tokens) {
            variable Integer firstTokIdx = getTokenIndexAtCharacter(tokens, regionOffset);
            // getTokenIndexAtCharacter() answers the negative of the index of the
            // preceding token if the given offset is not actually within a token.
            if (firstTokIdx < 0) {
                firstTokIdx = -firstTokIdx + 1;
            }
            variable Integer lastTokIdx = getTokenIndexAtCharacter(tokens, regionEnd);
            if (lastTokIdx < 0) {
                lastTokIdx = -lastTokIdx;
            }
            return tokens.subList(firstTokIdx, lastTokIdx + 1).iterator();
        }
        return null;
    }


    "This function returns the index of the token element
     containing the offset specified. If such a token does
     not exist, it returns the negation of the index of the
     element immediately preceding the offset."
    shared Integer getTokenIndexAtCharacter(JList<CommonToken> tokens, Integer offset) {
        //search using bisection
        variable Integer low = 0;
        variable Integer high = tokens.size();

        while (high > low) {
            Integer mid = (high + low) / 2;
            assert (is CommonToken midElement = tokens.get(mid));
            if (offset >= midElement.startIndex 
                && offset <= midElement.stopIndex) {
                return mid;
            } else if (offset < midElement.startIndex) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return -(low - 1);
    }

    shared Integer getNodeStartOffset(Node? node) 
            => node?.startIndex?.intValue() else 0;

    shared Integer getNodeEndOffset(Node? node) 
            => node?.endIndex?.intValue() else 0;

    "Get the Node referenced by the given model, searching
     in all relevant compilation units."
    shared Node? getReferencedNode(Referenceable? model) {
        if (exists model, is CeylonUnit unit = model.unit) {
            return getReferencedNodeInUnit(model, unit.compilationUnit);
        }
        return null;
    }
    
    shared Referenceable? getReferencedModel(Node node) {
        if (is Tree.ImportPath node) {
            value importPath = node;
            return importPath.model;
        } else if (is Tree.DocLink node) {
            value docLink = node;
            if (!docLink.base exists) {
                if (docLink.\imodule exists) {
                    return docLink.\imodule;
                }
                
                if (docLink.pkg exists) {
                    return docLink.pkg;
                }
            }
        }
        
        variable value dec = getReferencedDeclaration(node);
        if (is FunctionOrValue mv = dec) {
            if (mv.shortcutRefinement) {
                dec = mv.refinedDeclaration;
            }
        }
        
        return dec;
    }

    
    shared Referenceable? getReferencedExplicitDeclaration(Node? node, Tree.CompilationUnit? rn) {
        if (exists node, exists dec = getReferencedDeclaration(node)) {
            if (exists unit = dec.unit,
                exists nodeUnit = node.unit,
                unit==nodeUnit) {
                
                FindDeclarationNodeVisitor fdv =
                        FindDeclarationNodeVisitor(dec);
                fdv.visit(rn);
                
                if (is Tree.Variable decNode = fdv.declarationNode, 
                    is Tree.SyntheticVariable type = decNode.type) {
                    value term = decNode.specifierExpression.expression.term;
                    return getReferencedExplicitDeclaration(term, rn);
                }
            }
            return dec;
        }
        else {
            return null;
        }
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

    "Find the Node defining the given model within the given CompilationUnit."
    shared Node? getReferencedNodeInUnit(variable Referenceable? model, Tree.CompilationUnit? rootNode) {
        if (exists rootNode, exists m = model) {
            if (is Declaration decl = model) {
                if (exists unit = decl.unit, !unit.filename.lowercased.endsWith(".ceylon")) {
                    variable Boolean foundTheCeylonDeclaration = false;

                    if (is CeylonBinaryUnit<out Anything,out Anything,out Anything> unit,
                        is BaseIdeModule mod = unit.\ipackage.\imodule) {
                        value sourceRelativePath = mod.toSourceUnitRelativePath(unit.relativePath);
                        if (exists sourceRelativePath) {
                            value ceylonSourceRelativePath = mod.getCeylonDeclarationFile(sourceRelativePath);
                            if (exists ceylonSourceRelativePath) {
                                value externalPhasedUnit = mod.getPhasedUnitFromRelativePath(ceylonSourceRelativePath);
                                if (exists externalPhasedUnit) {
                                    value sourceFile = externalPhasedUnit.unit;
                                    
                                    for (sourceDecl in sourceFile.declarations) {
                                        if (sourceDecl.qualifiedNameString.equals(decl.qualifiedNameString)) {
                                            model = sourceDecl;
                                            foundTheCeylonDeclaration = true;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (!foundTheCeylonDeclaration) {
                        if (decl.native, !unit.filename.lowercased.endsWith(".ceylon")) {
                            if (exists headerDeclaration 
                                    = ModelUtil.getNativeHeader(decl)) {
                                if (exists overloads = headerDeclaration.overloads) {
                                    for (overload in overloads) {
                                        if (overload.nativeBackends.header()) {
                                            model = overload;
                                            foundTheCeylonDeclaration = true;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            value visitor = FindReferencedNodeVisitor(model);
            rootNode.visit(visitor);
            return visitor.declarationNode;
        }

        return null;
    }


    shared void appendParameters(StringBuilder result, Tree.FunctionArgument fa, Unit unit, NodePrinter printer) {
        for (pl in fa.parameterLists) {
            result.append("(");
            variable Boolean first = true;
            for (p in pl.parameters) {
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

    shared String? getImportedModuleName(Tree.ImportModule im) {
        if (exists ip = im.importPath) {
            return TreeUtil.formatPath(ip.identifiers);
        } else if (exists ql = im.quotedLiteral) {
            return ql.text;
        } else {
            return null;
        }
    }

    shared String? getImportedPackageName(Tree.Import im) {
        if (exists ip = im.importPath) {
            return TreeUtil.formatPath(ip.identifiers);
        } else {
            return null;
        }
    }
    
    shared String text(Node term, JList<CommonToken> tokens) {
        value start = term.startIndex.intValue();
        value length = term.endIndex.intValue() - start;
        value exp = StringBuilder();
        if (exists ti = getTokenIterator(tokens, DefaultRegion(start, length))) {
            while (ti.hasNext()) {
                value token = ti.next();
                value type = token.type;
                value text = token.text;
                if (type == CeylonLexer.\iLIDENTIFIER, getTokenLength(token) > text.size) {
                    exp.append("\\i");
                } else if (type == CeylonLexer.\iUIDENTIFIER, getTokenLength(token) > text.size) {
                    exp.append("\\I");
                }
                exp.append(text);
            }
        }
        return exp.string;
    }

    shared Integer getTokenLength(CommonToken token) 
            => token.stopIndex - token.startIndex + 1;

    shared ObjectArray<JString> nameProposals(Node? node, Boolean unplural = false, Tree.CompilationUnit? compilationUnit = null) {
        value names = HashSet<String>();

        if (is Tree.Term node) {
            Tree.Term term = TreeUtil.unwrapExpressionUntilTerm(node);
            Tree.Term typedTerm =
                    //TODO: is this really a good idea?!
                    if (is Tree.FunctionArgument term)
                    then (TreeUtil.unwrapExpressionUntilTerm(term.expression) else term)
                    else term;
            Type? type = typedTerm.typeModel;
            value baseTerm =
                if (is Tree.InvocationExpression inv = typedTerm)
                then TreeUtil.unwrapExpressionUntilTerm(inv.primary)
                else typedTerm;
            if(exists compilationUnit) {
                addArgumentNameProposals(names, compilationUnit, baseTerm);
            }

            /*if (is Tree.FunctionType ft = baseTerm,
                    is Tree.SimpleType returnType = ft.returnType) {
                addNameProposals(names, false, returnType.declarationModel.name);
            }*/

            switch (baseTerm)
            case (is Tree.QualifiedMemberOrTypeExpression) {
                if (exists decl = baseTerm.declaration) {
                    addNameProposals(names, false, decl.name);
                    //TODO: propose a compound name like personName for person.name
                }
            } case (is Tree.BaseMemberOrTypeExpression) {
                if (unplural) {
                    value name = baseTerm.declaration.name;
                    if (name.endsWith("s") && name.size > 1) {
                        addNameProposals(names, false, name[...name.size-1]);
                    }
                }
            } case (is Tree.SumOp) {
                names.add ("sum");
            } case (is Tree.DifferenceOp) {
                names.add ("difference");
            } case (is Tree.ProductOp) {
                names.add ("product");
            } case (is Tree.QuotientOp) {
                names.add ("ratio");
            } case (is Tree.RemainderOp) {
                names.add ("remainder");
            } case (is Tree.UnionOp) {
                names.add ("union");
            } case (is Tree.IntersectionOp) {
                names.add ("intersection");
            } case (is Tree.ComplementOp) {
                names.add ("complement");
            } case (is Tree.RangeOp) {
                names.add ("range");
            } case (is Tree.EntryOp) {
                names.add ("entry");
            } case (is Tree.StringLiteral) {
                addStringLiteralNameProposals(names, baseTerm);
            } else {}

            if (!ModelUtil.isTypeUnknown(type)) {
                assert (exists type);
                if (!unplural, type.classOrInterface || type.typeParameter) {
                    addNameProposals(names, false, type.declaration.name);
                }
                if (exists unit = node.unit) {
                    if (unit.isOptionalType(type),
                        exists def = unit.getDefiniteType(type),
                        def.classOrInterface || def.typeParameter) {
                        addNameProposals(names, false, def.declaration.name);
                    }
                    if (unit.isIterableType(type),
                        exists iter = unit.getIteratedType(type),
                        iter.classOrInterface || iter.typeParameter) {
                        addNameProposals(names, !unplural, iter.declaration.name);
                    }
                }
            }

        }

        if (names.empty) {
            names.add("it");
        }

        return createJavaStringArray(names);
    }
    
    "String literal name proposals:
     
     Name proposal from string value is constructed only if string value is not
     empty and contains only letters. 
     
     Name proposal is lowercase version of string literal value."
    void addStringLiteralNameProposals(HashSet<String> names, Tree.StringLiteral node) {
        String text = node.text;
        value matcher = wordPattern.matcher(javaString(text));
        if(matcher.matches()) {
            String unformatted = matcher.group();
            names.add(unformatted.lowercased);
        }
    }
    
    "Invocation argument value name proposals:
     
     For all cases with few exception proposed name is exact value of parameter
     name.
     
     For variadic parameters if more than one value is provided to it number 
     of parameter is appended to it.
     
     For anonymous arguments always number of parameter is appended to it.
     
     Proposals for indirect invocations are not supported.
     
     Proposals for arguments in not-first arguments lists of functions are not supported."
    void addArgumentNameProposals(HashSet<String> names, Tree.CompilationUnit compilationUnit, Tree.Term node) {
        [Tree.InvocationExpression?, Tree.SequencedArgument?, Tree.NamedArgument|Tree.PositionalArgument?]? argumentContext = findArgumentContext(compilationUnit, node);
        if(exists argumentContext) {
            value [invocationExpression, sequencedArgument, argument] = argumentContext;
            if(exists invocationExpression) {
                switch(argument)
                case (is Tree.NamedArgument) {
                    names.add(argument.identifier.text);
                } case (is Tree.PositionalArgument) {
                    Parameter? parameter = argument.parameter;
                    if(exists parameter) {
                        variable value name = parameter.name;
                        if(exists sequencedArgument) {
                            value index = sequencedArgument.positionalArguments.indexOf(argument);
                            if(index >= 0) {
                                name = name + (index + 1).string;
                            }
                        } else if (parameter.sequenced) {
                            Tree.PositionalArgumentList? positionalArgumentList = invocationExpression.positionalArgumentList;
                            if (exists positionalArgumentList) {
                                Tree.Primary? maybeParameterizedFunction = invocationExpression.primary;
                                Tree.Primary? \ifunction;
                                if(is Tree.ParameterizedExpression maybeParameterizedFunction) {
                                    \ifunction = maybeParameterizedFunction.primary;
                                } else {
                                    \ifunction = maybeParameterizedFunction;
                                }
                                if(is Tree.StaticMemberOrTypeExpression \ifunction) {
                                    Declaration? declaration = \ifunction.declaration;
                                    if(is Function|Class declaration) {
                                    JList<ParameterList> parameterLists = declaration.parameterLists;
                                        JList<Parameter> parameters = parameterLists.get(0).parameters;
                                        Integer position = positionalArgumentList.positionalArguments.indexOf(argument);
                                        if(parameters.contains(parameter) && parameters.size() < positionalArgumentList.positionalArguments.size()) {
                                            name += (position - parameters.size() + 2).string;
                                        }
                                    } 
                                }
                            }
                        }
                        names.add(name);
                    }
                } case (is Null) {}
            }
        }
    }

    shared void addNameProposals(
            MutableSet<String>|JSet<JString> names,
            Boolean plural, String name) {
        value matcher = idPattern.matcher(javaString(name));
        while (matcher.find()) {
            value subname =
                    matcher.group(1).lowercased +
                    name[matcher.start(2)...] +
                    (plural then "s" else "");
            value escaped = 
                    subname in keywords
                        then "\\i" + subname
                        else subname;
            if (is MutableSet<String> names) {
                names.add(escaped);
            } else {
                names.add(javaString(escaped));
            }
        }
        /*matcher.reset();
        while (matcher.find()) {
            value initials =
                    matcher.group(1).lowercased +
                    String(name.skip(matcher.start(2))
                               .filter(Character.uppercase)
                               .map(Character.lowercased)) +
                    (plural then "s" else "");
            if (!initials in keywords) {
                if (is MutableSet<String> names) {
                    names.add(initials);
                } else {
                    names.add(javaString(initials));
                }
            }
        }*/
    }
}

shared interface NodePrinter {
    shared formal String toString(Node node);
}
