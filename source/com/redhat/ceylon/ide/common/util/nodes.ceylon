import ceylon.collection {
    HashSet,
    MutableSet,
    SetMutator
}
import ceylon.interop.java {
    javaString
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
    CeylonUnit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Unit,
    ModelUtil,
    Declaration,
    FunctionOrValue,
    Function,
    Class,
    Type
}

import java.lang {
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
    
    [Tree.InvocationExpression?, Tree.SequencedArgument?, Tree.NamedArgument|Tree.PositionalArgument?]?
    findArgumentContext(Tree.CompilationUnit cu, Node node) {
        value visitor = FindArgumentContextVisitor(node);
        cu.visit(visitor);
        return visitor.context;
    }
    
    shared Tree.OperatorExpression? findOperator(Tree.CompilationUnit cu, Node node) {
        variable Tree.OperatorExpression? result = null;
        cu.visit(object extends Visitor() {
                shared actual void visit(Tree.OperatorExpression that) {
                    if (node.startIndex.intValue() >= that.startIndex.intValue(),
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
        if (exists container = ModelUtil.getContainingDeclaration(dec)) {
            variable Tree.Declaration? result = null;
            cu.visit(object extends Visitor() {
                    shared actual void visit(Tree.Declaration that) {
                        super.visit(that);
                        if (that.declarationModel==container) {
                            result = that;
                        }
                    }
                });
            return result;
        }
        else {
            return null;
        }
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
            variable Tree.ImportMemberOrType? result = null;
            object extends Visitor() {
                shared actual void visit(Tree.Declaration that) {}
                shared actual void visit(Tree.ImportMemberOrType that) {
                    super.visit(that);
                    if (exists dec = that.declarationModel,
                        exists d = declaration, dec == d) {
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
            } else if (node is Tree.MissingDeclaration) {
                return null;
            } else {
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
            } else if (exists p = node.quotedLiteral) {
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
            if (offset>=midElement.startIndex,
                offset<=midElement.stopIndex) {
                
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
        if (exists node, 
            exists dec = getReferencedDeclaration(node)) {
            if (exists unit = dec.unit,
                exists nodeUnit = node.unit,
                unit == nodeUnit) {
                
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
        } else {
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
                then qualified.get(qualified.size() - 1)
                else node.base;
        }
        case (is Tree.ImportPath) {
            return node.model;
        }
        else {
            return null;
        }
    }
    
    "Get the Node referenced by the given model, using the
     given [[rootNode]] if specified."
    shared Node? getReferencedNode(Referenceable? model,
            //TODO: this argument is probably always useless 
            Tree.CompilationUnit? rootNode = null) {
        if (!exists model) {
            return null;
        }
        
        if (exists rootNode) {
            return findReferencedNode(rootNode, model);
        }
        else if (is CeylonUnit unit = model.unit,
                exists node = unit.compilationUnit) {
            return findReferencedNode(node, model);
        }
        else {
            return null;
        }
    }
    
    shared void appendParameters(StringBuilder result, 
        Tree.FunctionArgument anonFunction, 
        Unit unit, JList<CommonToken> tokens) {
        for (pl in anonFunction.parameterLists) {
            result.append("(");
            variable Boolean first = true;
            for (p in pl.parameters) {
                if (first) {
                    first = false;
                } else {
                    result.append(", ");
                }
                
                if (is Tree.InitializerParameter p) {
                    value type = p.parameterModel.type;
                    if (!ModelUtil.isTypeUnknown(type)) {
                        result.append(type.asSourceCodeString(unit))
                              .append(" ");
                    }
                }
                result.append(text(tokens, p));
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
    
    shared String? getImportedPackageName(Tree.Import im)
            => if (exists ip = im.importPath)
            then TreeUtil.formatPath(ip.identifiers)
            else null;
    
    shared String text(JList<CommonToken> tokens, Node from, Node to = from) {
        value start = from.startIndex.intValue();
        value length = to.endIndex.intValue() - start;
        value exp = StringBuilder();
        if (exists tokenIterator 
                = getTokenIterator(tokens, 
                        DefaultRegion(start, length))) {
            while (tokenIterator.hasNext()) {
                value token = tokenIterator.next();
                value type = token.type;
                value text = token.text;
                if (type == CeylonLexer.lidentifier, 
                        getTokenLength(token) > text.size) {
                    exp.append("\\i");
                } else if (type == CeylonLexer.uidentifier, 
                        getTokenLength(token) > text.size) {
                    exp.append("\\I");
                }
                exp.append(text);
            }
        }
        return exp.string;
    }
    
    shared Integer getTokenLength(CommonToken token)
            => token.stopIndex - token.startIndex + 1;
    
    shared Set<String> renameProposals(node, rootNode = null) {
        "If given a [[Tree.Declaration]], suggest names based on the
         type of the term."
        Tree.Declaration? node;
        "If specified, and the given [[node]] occurs in an 
         argument list, suggest the name of the parameter."
        Tree.CompilationUnit? rootNode;
        
        value names = HashSet<String>();

        value dec = node?.declarationModel;
        if (!exists dec) {
            return names;
        }

        addNameProposals {
            names = names;
            plural = false;
            name = dec.name;
            lowercase = node is Tree.TypedDeclaration
                              | Tree.ObjectDefinition;
        };

        nameProposals {
            node = switch (node)
                case (is Tree.AttributeDeclaration)
                    node.specifierOrInitializerExpression?.expression
                case (is Tree.MethodDeclaration)
                    node.specifierExpression?.expression
                case (is Tree.Variable)
                    node.specifierExpression?.expression
                else null;
            rootNode = rootNode;
            unplural = false;
            avoidClash = true;
        }
        .filter(not("it".equals))
        .each(names.add);

        return names;
    }
    
    "Generates proposed names for provided node.
     
     Returned names are quoted to be valid text representing a 
     variable name."
    shared [String+] nameProposals(node, rootNode = null, unplural = false, avoidClash = true) {
        "If given a [[Tree.Term]], suggest names based on the
         type of the term."
       Tree.Term|Tree.Type? node;
        "Use English pluralization rules to find a singular 
         form of the proposed name."
        Boolean unplural;
        "Don't suggest a name if it would clash with a base
         reference within the given [[node]]."
        Boolean avoidClash;
        "If specified, and the given [[node]] occurs in an 
         argument list, suggest the name of the parameter."
        Tree.CompilationUnit? rootNode;
        
        value names = HashSet<String>();
        
        switch (node)
        case (null) {}
        case (is Tree.Type) {
            if (exists type = node.typeModel) {
                addNameProposalsForType(names, type, unplural, node.unit);
            }
        }
        case (is Tree.Term) {
            value term = TreeUtil.unwrapExpressionUntilTerm(node);
            value typedTerm =
                //TODO: is this really a good idea?!
                if (is Tree.FunctionArgument term)
                then (TreeUtil.unwrapExpressionUntilTerm(term.expression) else term)
                else term;
            value baseTerm =
                if (is Tree.InvocationExpression inv = typedTerm)
                then TreeUtil.unwrapExpressionUntilTerm(inv.primary)
                else typedTerm;
            if (exists rootNode) {
                addArgumentNameProposals(names, rootNode, baseTerm);
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
            }
            case (is Tree.BaseMemberOrTypeExpression) {
                if (exists decl = baseTerm.declaration) {
                    if (unplural) {
                        addNameProposals(names, false, singularize(decl.name));
                    }
                    else {
                        addNameProposals(names, false, decl.name);
                    }
                }
            }
            case (is Tree.SumOp) {
                names.add("sum");
            }
            case (is Tree.DifferenceOp) {
                names.add("difference");
            }
            case (is Tree.ProductOp) {
                names.add("product");
            }
            case (is Tree.QuotientOp) {
                names.add("ratio");
            }
            case (is Tree.RemainderOp) {
                names.add("remainder");
            }
            case (is Tree.UnionOp) {
                names.add("union");
            }
            case (is Tree.IntersectionOp) {
                names.add("intersection");
            }
            case (is Tree.ComplementOp) {
                names.add("complement");
            }
            case (is Tree.RangeOp) {
                names.add("range");
            }
            case (is Tree.EntryOp) {
                names.add("entry");
            }
            case (is Tree.StringLiteral) {
                addStringLiteralNameProposals(names, baseTerm);
            }
            else {}
            
            if (exists type = typedTerm.typeModel) {
                addNameProposalsForType(names, type, unplural, node.unit);
            }
        }
        
        if (avoidClash, exists node) {
            node.visit(object extends Visitor() {
                shared actual void visit(Tree.BaseMemberExpression that) {
                    if (exists decl = that.declaration) {
                        names.remove(decl.name);
                    }
                }
            });
        }
        
        return 
        if (nonempty result = names.sequence()) 
        then result else ["it"];
    }
    
    "String literal name proposals:
     
     Name proposal from string value is constructed only if string value is not
     empty and contains only letters. 
     
     Name proposal is lowercase version of string literal value.
     
     Appended names are quoted to be valid text representing a variable name."
    void addStringLiteralNameProposals(HashSet<String> names, Tree.StringLiteral node) {
        String text = node.text;
        value matcher = wordPattern.matcher(javaString(text));
        if (matcher.matches()) {
            String unformatted = matcher.group();
            names.add(escaping.escape(unformatted.lowercased));
        }
    }
    
    "Invocation argument value name proposals:
     
     For all cases with few exception proposed name is exact value of parameter
     name.
     
     For variadic parameters if more than one value is provided to it number 
     of parameter is appended to it.
     
     For anonymous arguments always number of parameter is appended to it.
     
     Proposals for indirect invocations are not supported.
     
     Proposals for arguments in not-first arguments lists of functions are not supported.
     
     Appended names are quoted to be valid text representing a variable name."
    void addArgumentNameProposals(MutableSet<String> names, Tree.CompilationUnit rootNode, Tree.Term node) {
        if (exists [invocationExpression, sequencedArgument, argument] 
                = findArgumentContext(rootNode, node)) {
            if (exists invocationExpression) {
                switch (argument)
                case (is Tree.NamedArgument) {
                    names.add(escaping.escapeInitialLowercase(argument.identifier.text));
                }
                case (is Tree.PositionalArgument) {
                    if (exists parameter = argument.parameter) {
                        variable value name = parameter.name;
                        if (exists sequencedArgument) {
                            value index = sequencedArgument.positionalArguments.indexOf(argument);
                            if (index >= 0) {
                                name = name + (index + 1).string;
                            }
                        } else if (parameter.sequenced) {
                            if (exists positionalArgumentList = invocationExpression.positionalArgumentList) {
                                Tree.Primary? maybeParameterizedFunction = invocationExpression.primary;
                                Tree.Primary? func 
                                        = if (is Tree.ParameterizedExpression maybeParameterizedFunction) 
                                        then maybeParameterizedFunction.primary 
                                        else maybeParameterizedFunction;
                                if (is Tree.StaticMemberOrTypeExpression func, 
                                    is Function|Class declaration = func.declaration) {
                                    value parameterLists = declaration.parameterLists;
                                    value parameters = parameterLists.get(0).parameters;
                                    Integer position = positionalArgumentList.positionalArguments.indexOf(argument);
                                    if (parameters.contains(parameter) && 
                                        parameters.size() < positionalArgumentList.positionalArguments.size()) {
                                        name += (position - parameters.size() + 2).string;
                                    }
                                }
                            }
                        }
                        names.add(escaping.escapeInitialLowercase(name));
                    }
                }
                case (null) {}
            }
        }
    }
    
    shared void addNameProposals(
        SetMutator<String>|JSet<JString> names,
        Boolean plural, String name,
        Boolean lowercase = true) {
        
        value matcher = idPattern.matcher(javaString(name));
        function lower(String str) 
                => lowercase then str.lowercased else str;
        while (matcher.find()) {
            value subname 
                    = lower(matcher.group(1)) 
                    + name[matcher.start(2) ...];
            value pluralized 
                    = plural 
                    then pluralize(subname) 
                    else subname; 
            value escaped =
                    pluralized in escaping.keywords
                        then "\\i" + pluralized
                        else pluralized;
            if (is SetMutator<String> names) {
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
    
    void addNameProposalsForType(SetMutator<String>|JSet<JString> names, 
            Type type, Boolean unplural, Unit? unit = null) {
        if (!ModelUtil.isTypeUnknown(type)) {
            if (!unplural, type.classOrInterface || type.typeParameter) {
                addNameProposals(names, false, type.declaration.name);
            }
            if (exists unit) {
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
                if (unit.isJavaIterableType(type),
                    exists iter = unit.getJavaIteratedType(type),
                    iter.classOrInterface || iter.typeParameter) {
                    addNameProposals(names, !unplural, iter.declaration.name);
                }
                if (unit.isJavaArrayType(type),
                    exists iter = unit.getJavaArrayElementType(type),
                    iter.classOrInterface || iter.typeParameter) {
                    addNameProposals(names, !unplural, iter.declaration.name);
                }
            }
        }
    }
    
    shared Tree.SpecifierOrInitializerExpression? getDefaultArgSpecifier(Tree.Parameter p) {
        if (is Tree.ValueParameterDeclaration p,
            is Tree.AttributeDeclaration pd = p.typedDeclaration) {

            return pd.specifierOrInitializerExpression;
        } else if (is Tree.FunctionalParameterDeclaration p,
                   is Tree.MethodDeclaration pd = p.typedDeclaration) {

            return pd.specifierExpression;
        } else if (is Tree.InitializerParameter p) {
            return p.specifierExpression;
        } else {
            return null;
        }
    }
}
