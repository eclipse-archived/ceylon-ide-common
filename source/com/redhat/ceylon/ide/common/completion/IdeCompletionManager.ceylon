import ceylon.interop.java {
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.compiler.typechecker.parser {
    Lexer=CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    OL=OccurrenceLocation,
    types,
    escaping,
    BaseProgressMonitor,
    RequiredType
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    Scope,
    Type,
    TypeDeclaration,
    Declaration,
    Class,
    TypedDeclaration,
    Unit,
    ModelUtil {
        isTypeUnknown
    },
    Function,
    Reference,
    Generic,
    TypeParameter,
    FunctionOrValue,
    ClassOrInterface,
    Functional,
    Constructor,
    Interface,
    Value,
    TypeAlias,
    Package,
    Cancellable
}

import java.lang {
    JString=String
}
import java.util {
    Map,
    HashMap,
    JList=List,
    Collection,
    Collections,
    JArrayList=ArrayList,
    TreeSet
}

import org.antlr.runtime {
    CommonToken,
    Token
}


shared object completionManager
        satisfies InvocationCompletion
                & ParametersCompletion
                & KeywordCompletion
                & MemberNameCompletion
                & BasicCompletion
                & RefinementCompletion
                & PackageCompletion
                & TypeArgumentListCompletions
                & ModuleCompletion
                & FunctionCompletion
                & ControlStructureCompletionProposal
                & AnonFunctionCompletion {

    shared alias Proposals => Map<JString,DeclarationWithProximity>;

    Proposals noProposals = HashMap<JString,DeclarationWithProximity>();

    // see CeylonCompletionProcessor.sortProposals()
    function sortProposals(String prefix, 
        RequiredType required, Proposals proposals) {
        value set = TreeSet(ProposalComparator(prefix, required));
        set.addAll(proposals.values());
        return set;
    }
    
    // see CeylonCompletionProcessor.getContentProposals(CeylonParseController,
    // int, ITextViewer, boolean, boolean, IProgressMonitor)
    shared void getContentProposals(
        Tree.CompilationUnit typecheckedRootNode, 
        CompletionContext ctx, 
        Integer offset, Integer line, Boolean secondLevel, 
        BaseProgressMonitor monitor, 
        Boolean returnedParamInfo = false) {

        value tokens = ctx.tokens;
        value document = ctx.commonDocument;
        
        //adjust the token to account for unclosed blocks
        //we search for the first non-whitespace/non-comment
        //token to the left of the caret
        variable Integer tokenIndex 
                = nodes.getTokenIndexAtCharacter(tokens, offset);
        if (tokenIndex < 0) {
            tokenIndex = -tokenIndex;
        }
        value adjustedToken = adjust(tokenIndex, offset, tokens);
        value tt = adjustedToken.type;
        
        if (offset <= adjustedToken.stopIndex,
            offset > adjustedToken.startIndex,
            isCommentOrCodeStringLiteral(adjustedToken)) {
            
            return;
        }
        if (isLineComment(adjustedToken),
            offset > adjustedToken.startIndex,
            adjustedToken.line == line + 1) {
            
            return;
        }

        //find the node at the token
        value node = getTokenNode {
            adjustedStart = adjustedToken.startIndex;
            adjustedEnd = adjustedToken.stopIndex + 1;
            tokenType = tt;
            rootNode = typecheckedRootNode;
            offset = offset;
        };

        //it's useful to know the type of the preceding token, if any
        variable Integer index = adjustedToken.tokenIndex;
        if (offset <= adjustedToken.stopIndex+1, 
            offset > adjustedToken.startIndex) {
            index--;
        }
        value tokenType = adjustedToken.type;
        value previousTokenType 
                = if (index >= 0) 
                then adjust(index, offset, tokens).type 
                else -1;

        //find the type that is expected in the current
        //location so we can prioritize proposals of that
        //type
        //TODO: this breaks as soon as the user starts typing
        //      an expression, since RequiredTypeVisitor
        //      doesn't know how to search up the tree for
        //      the containing InvocationExpression
        value required = types.getRequiredType {
            rootNode = typecheckedRootNode;
            node = node;
            token = adjustedToken;
        };
        variable String prefix = "";
        variable String fullPrefix = "";
        
        if (isIdentifierOrKeyword(adjustedToken)) {
            String text = adjustedToken.text;
            //work from the end of the token to
            //compute the offset, in order to
            //account for quoted identifiers, where
            //the \i or \I is not in the token text 
            value offsetInToken = offset - adjustedToken.stopIndex - 1 + text.size;
            value realOffsetInToken = offset - adjustedToken.startIndex;
            if (offsetInToken <= text.size) {
                prefix = text.spanTo(offsetInToken - 1);
                fullPrefix = getRealText(adjustedToken)
                            .spanTo(realOffsetInToken - 1);
            }
        }
        variable Boolean isMemberOp = isMemberOperator(adjustedToken);
        variable String qualified = "";
        
        // special handling for doc links
        Boolean inDoc 
                = isAnnotationStringLiteral(adjustedToken)
                && offset>adjustedToken.startIndex
                && offset<=adjustedToken.stopIndex;

        if (inDoc) {
            if (is Tree.DocLink node) {
                Tree.DocLink docLink = node;
                Integer offsetInLink 
                        = offset - docLink.startIndex.intValue();
                String text = docLink.token.text;
                Integer bar = (text.firstOccurrence('|') else -1) + 1;
                if (offsetInLink < bar) { 
                    return;
                }
                qualified = text.span(bar, offsetInLink - 1);
                Integer dcolon = qualified.firstInclusion("::") else -1;
                variable String? pkg = null;
                if (dcolon >= 0) {
                    pkg = qualified.spanTo(dcolon + 1);
                    qualified = qualified.spanFrom(dcolon + 2);
                }
                Integer dot = (qualified.firstOccurrence('.') else -1) + 1;
                isMemberOp = dot > 0;
                prefix = qualified.spanFrom(dot);
                if (dcolon >= 0) {
                    assert(exists p = pkg); 
                    qualified = p + qualified;
                }
                fullPrefix = prefix;
            } else { 
                return;
            }
        }
        
        value fsv = FindScopeVisitor(node);
        fsv.visit(typecheckedRootNode);
        value scope = fsv.scope;

        // I think the rest of this function assumes the scope always exists
        if (!exists scope) {
            return;
        }
        
        //construct completions when outside ordinary code
        constructCompletionsOutsideOrdinaryCode {
            offset = offset;
            prefix = fullPrefix;
            ctx = ctx;
            node = node;
            token = adjustedToken;
            scope = scope;
            returnedParamInfo = returnedParamInfo;
            memberOp = isMemberOp;
            tokenType = tokenType;
            monitor = monitor;
        };
        
        if (ctx.proposals.empty) {
            value proposals = getProposals {
                node = node;
                scope = scope;
                prefix = prefix;
                memberOp = isMemberOp;
                rootNode = typecheckedRootNode;
                cancellable = monitor;
            };
            /*value functionProposals = getFunctionProposals {
                node = node;
                scope = scope;
                prefix = prefix;
                memberOp = isMemberOp;
                cancellable = monitor;
            };*/
            
            filterProposals(ctx, proposals);
//            filterProposals(ctx, functionProposals);

            value before = system.milliseconds;
            constructCompletions {
                offset = offset;
                prefix = inDoc then qualified else fullPrefix;
                sortedProposals
                        = proposals.values();
                        /*= sortProposals {
                            prefix = prefix;
                            required = required;
                            proposals = proposals;
                        };*/
                sortedFunctionProposals
                        = Collections.emptyList<DeclarationWithProximity>();
                        /*= sortProposals {
                            prefix = prefix;
                            required = required;
                            proposals = functionProposals;
                        };*/
                ctx = ctx;
                scope = scope;
                node = node;
                token = adjustedToken;
                memberOp = isMemberOp;
                doc = document;
                secondLevel = secondLevel;
                inDoc = inDoc;
                requiredType = required.type;
                previousTokenType = previousTokenType;
                tokenType = tokenType;
                cancellable = monitor;
            };
            print("constructed completions in ``system.milliseconds - before``ms => ``ctx.proposals.size`` results");
        }
    }
    
    void constructCompletionsOutsideOrdinaryCode(
        Integer offset, String prefix, CompletionContext ctx,
        Node node, CommonToken token, Scope scope, 
        Boolean returnedParamInfo, Boolean memberOp,
        Integer tokenType, BaseProgressMonitor monitor) {

        if (!returnedParamInfo, 
            atStartOfPositionalArgument(node, token)) {

            addFakeShowParametersCompletion(node, ctx);
        }
        else if (is Tree.PackageLiteral node) {
            addPackageCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = null;
                node = node;
                withBody = false;
                monitor = monitor;
            };
        }
        else if (is Tree.ModuleLiteral node) {
            addModuleCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = null;
                node = node;
                withBody = false;
                monitor = monitor;
            };
        }
        else if (isDescriptorPackageNameMissing(node)) {
            addCurrentPackageNameCompletion {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
            };
        }
        else if (node is Tree.Import, 
                offset > token.stopIndex+1) {

            addPackageCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = null;
                node = node;
                withBody = nextTokenType(ctx, token) != Lexer.lbrace;
                monitor = monitor;
            };
        }
        else if (node is Tree.ImportModule, 
                offset > token.stopIndex+1) {

            addModuleCompletions {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                path = null;
                node = node;
                withBody
                        = nextTokenType(ctx, token)
                            != Lexer.stringLiteral;
                monitor = monitor;
            };
        }
        else if (is Tree.ImportPath node) {
            ImportVisitor {
                prefix = prefix;
                token = token;
                offset = offset;
                node = node;
                ctx = ctx;
                monitor = monitor;
            }.visit(ctx.lastCompilationUnit);
        }
        else if (isEmptyModuleDescriptor(ctx.lastCompilationUnit)) {
            addModuleDescriptorCompletion(ctx, offset, prefix);
            addKeywordProposals {
                ctx = ctx;
                cu = ctx.lastCompilationUnit;
                offset = offset;
                prefix = prefix;
                node = node;
                ol = null;
                postfix = false;
                previousTokenType = tokenType;
            };
        }
        else if (isEmptyPackageDescriptor(ctx.lastCompilationUnit)) {
            addPackageDescriptorCompletion(ctx, offset, prefix);
            addKeywordProposals {
                ctx = ctx;
                cu = ctx.lastCompilationUnit;
                offset = offset;
                prefix = prefix;
                node = node;
                ol = null;
                postfix = false;
                previousTokenType = tokenType;
            };
        }
        else if (node is Tree.TypeArgumentList, 
            token.type == Lexer.largerOp) {
            
            if (offset == token.stopIndex+1) {
                addTypeArgumentListProposal {
                    offset = offset;
                    ctx = ctx;
                    node = node;
                    scope = scope;
                };
            }
            else if (isMemberNameProposable(offset, node, memberOp)) {
                addMemberNameProposals {
                    offset = offset;
                    ctx = ctx;
                    node = node;
                };
            }
        }
    }

    Boolean isDescriptorPackageNameMissing(Node node) {
        Tree.ImportPath? path;
        switch (node)
        case (is Tree.ModuleDescriptor) {
            path = node.importPath;
        }
        case (is Tree.PackageDescriptor) {
            path = node.importPath;
        } else {
            return false;
        }
        return path?.identifiers?.empty else true;
    }


    Boolean atStartOfPositionalArgument(Node node, CommonToken token) {
        if (is Tree.PositionalArgumentList node) {
            value type = token.type;
            return type == Lexer.lparen
                || type == Lexer.comma;
        } else if (is Tree.NamedArgumentList node) {
            value type = token.type;
            return type == Lexer.lbrace
                || type == Lexer.semicolon;
        } else {
            return false;
        }
    }

    // see CeylonCompletionProcessor.
    void filterProposals(CompletionContext ctx, Proposals proposals) {
        value filters = ctx.proposalFilters;
        if (!filters.empty) {
            value iterator = proposals.values().iterator();
            while (iterator.hasNext()) {
                value dwp = iterator.next();
                String name = dwp.declaration.qualifiedNameString;
                for (filter in filters) {
                    if (filter.matcher(javaString(name)).matches()) {
                        iterator.remove();
                    }
                }
            }
        }
    }
    
    // see CeylonCompletionProcessor.isAnnotationStringLiteral()
    Boolean isAnnotationStringLiteral(CommonToken token) {
        Integer type = token.type;
        return type == Lexer.astringLiteral
            || type == Lexer.averbatimString;
    }

    // see CeylonCompletionProcessor.isMemberOperator()
    Boolean isMemberOperator(Token token) {
        Integer type = token.type;
        return type == Lexer.memberOp 
            || type == Lexer.spreadOp 
            || type == Lexer.safeMemberOp;
    }
    
    // see CeylonCompletionProcessor.getRealText()
    String getRealText(CommonToken token) {
        String text = token.text;
        Integer type = token.type;
        Integer len = token.stopIndex - token.startIndex + 1;
        if (text.size < len) {
            String quote;
            if (type == Lexer.lidentifier) {
                quote = "\\i";
            }
            else if (type == Lexer.uidentifier) {
                quote = "\\I";
            }
            else {
                quote = "";
            }
            return quote + text;
        } else {
            return text;
        }
    }

    // see CeylonCompletionProcessor.getTokenNode()
    Node getTokenNode(Integer adjustedStart, 
        Integer adjustedEnd, Integer tokenType, 
        Tree.CompilationUnit rootNode, Integer offset) {
        variable value node
                = nodes.findNode {
                    node = rootNode;
                    tokens = null;
                    startOffset = adjustedStart;
                    endOffset = adjustedEnd;
                };
        if (is Tree.StringLiteral sl = node, !sl.docLinks.empty) {
            node = nodes.findNode(sl, null, offset, offset);
        }
        if (tokenType == Lexer.rbrace && !node is Tree.IterableType
            || tokenType == Lexer.semicolon) {

            //We are to the right of a } or ;
            //so the returned node is the previous
            //statement/declaration. Look for the
            //containing body.
            class BodyVisitor extends Visitor {
                Node node;
                variable Node currentBody;
                shared variable Node? result = null;

                shared new (Node node, Node root) extends Visitor() {
                    this.node = node;
                    currentBody = root;
                }
                
                shared actual void visitAny(Node that) {
                    if (that === node) {
                        result = currentBody;
                    } else {
                        Node cb = currentBody;
                        if (is Tree.Body that) {
                            currentBody = that;
                        }
                        if (is Tree.NamedArgumentList that) {
                            currentBody = that;
                        }
                        super.visitAny(that);
                        currentBody = cb;
                    }
                }
            }
            
            if (exists n = node) {
                BodyVisitor mv = BodyVisitor(n, rootNode);
                mv.visit(rootNode);
                node = mv.result;
            }
        }
        
        return node else rootNode; //we're in whitespace at the start of the file
    }

    // see CeylonCompletionProcessor.isIdentifierOrKeyword()
    Boolean isIdentifierOrKeyword(Token token) {
        value type = token.type;
        return type == Lexer.lidentifier
                || type == Lexer.uidentifier 
                || type == Lexer.aidentifier 
                || type == Lexer.pidentifier 
                || escaping.isKeyword(token.text);
    }

    // see CeylonCompletionProcessor.isCommentOrCodeStringLiteral()
    Boolean isCommentOrCodeStringLiteral(CommonToken adjustedToken) {
        Integer tt = adjustedToken.type;
        return tt == Lexer.multiComment
            || tt == Lexer.lineComment
            || tt == Lexer.stringLiteral
            || tt == Lexer.stringEnd
            || tt == Lexer.stringMid
            || tt == Lexer.stringStart
            || tt == Lexer.verbatimString
            || tt == Lexer.charLiteral
            || tt == Lexer.floatLiteral
            || tt == Lexer.naturalLiteral;
    }
    
    // see CeylonCompletionProcessor.isLineComment()
    Boolean isLineComment(variable CommonToken adjustedToken) {
        return adjustedToken.type == Lexer.lineComment;
    }

    Type? getFunctionProposalType(Node node, Boolean memberOp) {
        if (is Tree.QualifiedMemberOrTypeExpression node,
            !node.staticMethodReference,
            exists type = getPrimaryType(node)) {
            return type;
        }
        else if (memberOp,
            is Tree.Term node,
            exists type = node.typeModel) {
            return type;
        }
        else {
            return null;
        }
    }

    Proposals getFunctionProposals(Node node,
            Scope scope, String prefix, Boolean memberOp, 
            Cancellable? cancellable)
            => if (exists type
                    = getFunctionProposalType(node, memberOp),
                    !isTypeUnknown(type))
            then collectUnaryFunctions(type,
                scope.getMatchingDeclarations(node.unit,
                    prefix, 0, cancellable))
            else noProposals;

    Proposals collectUnaryFunctions(Type type,
            Proposals candidates) {
        value matches
                = HashMap<JString,DeclarationWithProximity>();

        for (candidate in candidates.entrySet()) {
            if (is Function declaration
                    = candidate.\ivalue.declaration,
                !declaration.annotation,
                !declaration.parameterLists.empty) {

                value params =
                        declaration.firstParameterList
                            .parameters;
                if (!params.empty) {
                    variable Boolean unary = true;
                    if (params.size() > 1) {
                        for (i in 1..params.size()-1) {
                            if (!params.get(i).defaulted) {
                                unary = false;
                            }
                        }
                    }

                    if (unary,
                            exists t = params[0]?.type,
                            !isTypeUnknown(t),
                            type.isSubtypeOf(t)) {
                        matches.put(candidate.key,
                            candidate.\ivalue);
                    }
                }
            }
        }

        return matches;
    }


    Boolean isQualifiedType(Node node)
            => if (is Tree.QualifiedMemberOrTypeExpression node)
                then node.staticMethodReference
                else node is Tree.QualifiedType;

    // see CeylonCompletionProcess.constructCompletions(...)
    void constructCompletions(
        Integer offset, String prefix,
        Collection<DeclarationWithProximity> sortedProposals,
        Collection<DeclarationWithProximity> sortedFunctionProposals,
        CompletionContext ctx, Scope scope,
        Node node, CommonToken token,
        Boolean memberOp, CommonDocument doc,
        Boolean secondLevel, Boolean inDoc,
        Type? requiredType, Integer previousTokenType,
        Integer tokenType,
        Cancellable cancellable) {

        value cu = ctx.lastCompilationUnit;
        value ol = nodes.getOccurrenceLocation(cu, node, offset);
        value unit = node.unit;
        value addParameterTypesInCompletions 
                = ctx.options.parameterTypesInCompletion;
        value inexactMatches
                = let (pref = ctx.options.inexactMatches)
                pref in ["both", "positional"];

        if (is Tree.Term node) {
            addParametersProposal {
                offset = offset;
                prefix = prefix;
                node = node;
                ctx = ctx;
            };
        }
        else if (is Tree.ArgumentList node) {
            value fiv = FindInvocationVisitor(node);
            fiv.visit(cu);
            if (exists ie = fiv.result) {
                addParametersProposal {
                    offset = offset;
                    prefix = prefix;
                    node = ie;
                    ctx = ctx;
                };
            }
        }

        if (is Tree.TypeConstraint node) {
            for (dwp in sortedProposals) {
                value dec = dwp.declaration;
                if (isTypeParameterOfCurrentDeclaration(node, dec)) {
                    addReferenceProposal(cu, offset, prefix, ctx,
                        dwp, null, scope, ol, false);
                }
            }
        }
        else if (prefix.empty, 
            !isLocation(ol, OL.\iis),
            isMemberNameProposable(offset, node, memberOp),
            is Tree.Type
             | Tree.BaseTypeExpression
             | Tree.QualifiedTypeExpression node) {
            
            //member names we can refine
            if (exists t 
                    = if (is Tree.Type node)
                    then node.typeModel
                    else node.target?.type) {
                addRefinementProposals(offset,
                        sortedProposals, ctx, scope, node, doc,
                        secondLevel, ol, t, false);
            }
            //otherwise guess something from the type
            addMemberNameProposal(ctx, offset, prefix, node, cu);
        }
        else if (is Tree.TypedDeclaration node, 
            !(node is Tree.Variable 
                && node.type is Tree.SyntheticVariable),
            //!(node is Tree.InitializerParameter),
            isMemberNameProposable(offset, node, memberOp)) {
            
            //member names we can refine
            if (exists dnt = node.type, exists t = dnt.typeModel) {
                addRefinementProposals(offset, sortedProposals, 
                        ctx, scope, node, doc, secondLevel, 
                        ol, t, true);
            }
            //otherwise guess something from the type
            addMemberNameProposal(ctx, offset, prefix, node, cu);
        }
        else {
            value isMember
                    = if (is Tree.MemberLiteral node)
                    then node.type exists
                    else node is Tree.QualifiedMemberOrTypeExpression
                               | Tree.QualifiedType;

            if (!secondLevel, !inDoc, !memberOp) {
                addKeywordProposals {
                    ctx = ctx;
                    cu = ctx.lastCompilationUnit;
                    offset = offset;
                    prefix = prefix;
                    node = node;
                    ol = ol;
                    postfix = isMember;
                    previousTokenType = tokenType;
                };
            }
            if (!secondLevel, !inDoc, !isMember,
                    prefix.empty, 
                    !ModelUtil.isTypeUnknown(requiredType), 
                    unit.isCallableType(requiredType)) {
                addAnonFunctionProposal {
                    ctx = ctx;
                    offset = offset;
                    requiredType = requiredType;
                    unit = unit;
                };
            }

            value isPackageOrModuleDescriptor
                    = isModuleDescriptor(cu) 
                    || isPackageDescriptor(cu);

            for (dwp in sortedProposals) {
                value dec = dwp.declaration;

                if (!dec.toplevel,
                    !dec.classOrInterfaceMember, 
                    dec.unit == unit,
                    exists decNode = nodes.getReferencedNode(dec, cu),
                    exists id = nodes.getIdentifyingNode(decNode), 
                    offset < id.startIndex.intValue()) {
                    continue;
                }

                if (isPackageOrModuleDescriptor, !inDoc, 
                    !isLocation(ol, OL.meta),
                    !(ol?.reference else false),
                    !dec.annotation || !dec is Function) {
                    continue;
                }

                if (!secondLevel,
                        isParameterOfNamedArgInvocation(scope, dwp),
                        isDirectlyInsideNamedArgumentList(ctx, node, token)) {
                    addNamedArgumentProposal {
                        offset = offset;
                        prefix = prefix;
                        ctx = ctx;
                        dec = dec;
                        scope = scope;
                    };
                    addInlineFunctionProposal {
                        offset = offset;
                        dec = dec;
                        scope = scope;
                        node = node;
                        prefix = prefix;
                        ctx = ctx;
                        doc = doc;
                    };
                }

                value nextToken = getNextToken(ctx, token);
                value noParamsFollow = noParametersFollow(nextToken);

                if (!secondLevel, !inDoc, noParamsFollow,
                    isInvocationProposable {
                        dwp = dwp;
                        ol = ol;
                        previousTokenType = previousTokenType;
                        unit = unit;
                        prefix = prefix;
                        inexactMatches = inexactMatches;
                    },
                    !isQualifiedType(node) 
                            || ModelUtil.isConstructor(dec) 
                            || dec.staticallyImportable,
                    if (is Constructor scope)
                        then !isLocation(ol, OL.\iextends) 
                            || isDelegatableConstructor(scope, dec)
                        else true) {
                    for (d in overloads(dec)) {
                        addInvocationProposals {
                            offset = offset;
                            prefix = prefix;
                            ctx = ctx;
                            dwp = dwp;
                            dec = d;
                            reference
                                    = if (isMember)
                                    then getQualifiedProducedReference(node, d)
                                    else getRefinedProducedReference(scope, d);
                            scope = scope;
                            ol = ol;
                            typeArgs = null;
                            isMember = isMember;
                        };
                    }
                }

                if (isProposable {
                        dwp = dwp;
                        ol = ol;
                        scope = scope;
                        unit = unit;
                        requiredType = requiredType;
                        previousTokenType = previousTokenType;
                    },
                    isProposableBis(node, ol, dec),
                    (definitelyRequiresType(ol) 
                        || noParamsFollow 
                        || dec is Functional),
                    (!scope is Constructor 
                        || !isLocation(ol, OL.\iextends) 
                        || isDelegatableConstructor(scope, dec))) {

                    if (isLocation(ol, OL.doclink)) {
                        addDocLinkProposal(offset, prefix, ctx, dec, scope);
                    }
                    else if (isLocation(ol, OL.\iimport)) {
                        addImportProposal(offset, prefix, ctx, dec, scope);
                    }
                    else if (ol?.reference else false) {
                        if (isReferenceProposable(ol, dec)) {
                            addProgramElementReferenceProposal {
                                offset = offset;
                                prefix = prefix;
                                ctx = ctx;
                                dec = dec;
                                scope = scope;
                                isMember = isMember;
                            };
                        }
                    }
                    else {
                        if (secondLevel,
                            exists reference =
                                    if (isMember)
                                    then getQualifiedProducedReference(node, dec)
                                    else getRefinedProducedReference(scope, dec)) {
                            addSecondLevelProposal {
                                offset = offset;
                                prefix = prefix;
                                ctx = ctx;
                                dec = dec;
                                scope = scope;
                                isMember = false;
                                reference = reference;
                                requiredType = requiredType;
                                ol = ol;
                                cancellable = cancellable;
                            };
                        }
                        else if (!dec is Function 
                                || !ModelUtil.isAbstraction(dec) 
                                || !noParamsFollow) {
                            addReferenceProposal {
                                cu = cu;
                                offset = offset;
                                prefix = prefix;
                                ctx = ctx;
                                dwp = dwp;
                                reference =
                                        if (dwp.unimported) then null
                                        else if (isMember)
                                        then getQualifiedProducedReference(node, dec)
                                        else getRefinedProducedReference(scope, dec);
                                scope = scope;
                                ol = ol;
                                isMember = isMember;
                            };
                        }
                    }
                }

                if (!memberOp, !secondLevel,
                    isProposable {
                        dwp = dwp;
                        ol = ol;
                        scope = scope;
                        unit = unit;
                        requiredType = requiredType;
                        previousTokenType = previousTokenType;
                    }, 
                    !isLocation(ol, OL.\iimport),
                    !isLocation(ol, OL.\icase),
                    !isLocation(ol, OL.\icatch),
                    isDirectlyInsideBlock(node, ctx, scope, token)) {
                    
                    addForProposal(offset, prefix, ctx, dwp, dec);
                    addIfExistsProposal(offset, prefix, ctx, dwp, dec);
                    addAssertExistsProposal(offset, prefix, ctx, dwp, dec);
                    addIfNonemptyProposal(offset, prefix, ctx, dwp, dec);
                    addAssertNonemptyProposal(offset, prefix, ctx, dwp, dec);
                    addTryProposal(offset, prefix, ctx, dwp, dec);
                    addSwitchProposal(offset, prefix, ctx, dwp, dec, node);
                }
                
                if (!memberOp, !isMember, !secondLevel) {
                    for (d in overloads(dec)) {
                        if (isRefinementProposable(d, ol, scope), 
                            is ClassOrInterface scope) {
                            addRefinementProposal {
                                offset = offset;
                                dec = d;
                                ci = scope;
                                node = node;
                                scope = scope;
                                prefix = prefix;
                                ctx = ctx;
                                preamble = true;
                                addParameterTypesInCompletions 
                                        = addParameterTypesInCompletions;
                            };
                        }
                    }
                }
            }
        }

        if (node is Tree.QualifiedMemberExpression
            || memberOp && node is Tree.QualifiedTypeExpression) {
            
            assert (is Tree.QualifiedMemberOrTypeExpression node);
            
            for (dwp in sortedFunctionProposals) {
                value primary = node.primary;
                addFunctionProposal {
                    offset = offset;
                    ctx = ctx;
                    primary = primary;
                    dec = dwp.declaration;
                };
            }
            
            if (is Tree.StaticMemberOrTypeExpression bme = node.primary,
                exists declaration = bme.declaration) {
                
                value dwp = DeclarationWithProximity(declaration, 0);
                // we don't care what the text is, we just need the correct length
                value textToReplace = "-".repeat(offset - node.startIndex.intValue());
                // the expression to wrap, may need to be assigned
                value expr
                        = (if (is Tree.BaseMemberExpression bme)
                            then "" else "val = ")
                        + doc.getText {
                            offset = bme.startIndex.intValue();
                            length = bme.distance.intValue();
                        };
                
                addIfExistsProposal(offset, textToReplace, ctx,
                    dwp, declaration, bme, expr);
            }
        }
        if (previousTokenType==Lexer.objectDefinition) {
            addKeywordProposals(ctx, cu, offset, prefix, 
                node, ol, false, tokenType);
        }
    }

    Boolean isDirectlyInsideBlock(Node node, CompletionContext ctx,
        Scope scope, CommonToken token)
            => !scope is Interface|Package &&
               !node is Tree.SequenceEnumeration
            && occursAfterBraceOrSemicolon(token, ctx.tokens);

    // see CeylonParseController.isMemberNameProposable(int offset, Node node, boolean memberOp)
    Boolean isMemberNameProposable(Integer offset, Node node, Boolean memberOp)
            => if (!memberOp,
                   is CommonToken token = node.endToken,
                   token.stopIndex >= offset-2)
                then true else false;

    Reference? getQualifiedProducedReference(Node node, Declaration d) {
        if (is TypeDeclaration container = d.container) {
            Type? type;
            switch (node)
            case (is Tree.QualifiedMemberOrTypeExpression) {
                type = node.primary.typeModel;
            }
            case (is Tree.QualifiedType) {
                type = node.outerType.typeModel;
            }
            else {
                return null;
            }

            if (exists type) {
                value supertype = type.getSupertype(container);
                return d.appliedReference(supertype, Collections.emptyList<Type>());
            }
        }
        return d.appliedReference(null, Collections.emptyList<Type>());
    }

    /*Reference? getRefinedProducedReferenceForSupertype(Type typeOrScope, Declaration d) {
        if (typeOrScope.intersection) {
            for (pt in typeOrScope.satisfiedTypes) {
                if (exists result
                        = getRefinedProducedReferenceForSupertype(pt, d)) {
                    return result;
                }
            }
            return null; //never happens?
        } else {
            if (exists declaringType
                    = typeOrScope.declaration.getDeclaringType(d)) {
                Type outerType
                        = typeOrScope.getSupertype(declaringType.declaration);
                return refinedProducedReference(outerType, d);
            }
            return null;
        }
    }*/

    Reference? getRefinedProducedReference(Scope scope, Declaration d) {
        JList<Type> params;
        if (is Generic d) {
            params = JArrayList<Type>();
            for (tp in d.typeParameters) {
                params.add(tp.type);
            }
        }
        else {
            params = Collections.emptyList<Type>();
        }
        value outerType = !d.toplevel then scope.getDeclaringType(d);
        return d.appliedReference(outerType, params);
    }

    /*Reference refinedProducedReference(Type outerType, Declaration d) {
        JList<Type> params;
        if (is Generic d) {
            params = JArrayList<Type>();
            for (tp in d.typeParameters) {
                params.add(tp.type);
            }
        }
        else {
            params = Collections.emptyList<Type>();
        }
        return d.appliedReference(outerType, params);
    }*/

    Boolean isTypeParameterOfCurrentDeclaration(Node node, Declaration d) {
        //TODO: this is a total mess and totally error-prone
        //       - figure out something better!
        if (is TypeParameter tp = d) {
            Scope tpc = tp.container;
            if (tpc == node.scope) {
                return true;
            }
            else if (is Tree.TypeConstraint constraint = node){
                return if (exists tcp = constraint.declarationModel,
                           tpc==tcp.container)
                       then true
                       else false;
            }
        }
        return false;
    }

    void addRefinementProposals(Integer offset,
        Collection<DeclarationWithProximity> set,
        CompletionContext ctx, Scope scope,
        Node node, CommonDocument doc, Boolean filter,
        OL? ol, Type t,
        Boolean preamble) {

        value addParameterTypesInCompletions 
                = ctx.options.parameterTypesInCompletion;
        
        for (dwp in set) {
            if (!filter, is FunctionOrValue dec = dwp.declaration) {
                for (d in overloads(dec)) {
                    if (isRefinementProposable(d, ol, scope),
                        isReturnType(t, dec, node),
                        is ClassOrInterface scope) {
                        value start = node.startIndex.intValue();
                        addRefinementProposal {
                            offset = offset;
                            dec = d;
                            ci = scope;
                            node = node;
                            scope = scope;
                            prefix = doc.getText {
                                offset = 0;
                                length = offset - start;
                            };
                            ctx = ctx;
                            preamble = preamble;
                            addParameterTypesInCompletions 
                                    = addParameterTypesInCompletions;
                        };
                    }
                }
            }
        }
    }

    Boolean isRefinementProposable(Declaration dec, OL? ol, Scope scope)
            => (ol is Null || isAnonymousClass(scope)) &&
                (dec.default || dec.formal) &&
                (dec is FunctionOrValue || dec is Class) &&
                (if (is ClassOrInterface scope)
                 then scope.isInheritedFromSupertype(dec)
                 else false);
    
    Boolean isAnonymousClass(Scope scope)
            => if (is Class scope) then scope.anonymous else false;

    Boolean isParameterOfNamedArgInvocation(Scope scope, DeclarationWithProximity d)
            => if (exists nal = d.namedArgumentList, scope == nal) then true else false;

    Boolean isDirectlyInsideNamedArgumentList(CompletionContext ctx,
        Node node, CommonToken token)
            => node is Tree.NamedArgumentList ||
              !node is Tree.SequenceEnumeration
                && occursAfterBraceOrSemicolon(token, ctx.tokens);

    // see CeylonCompletionProcessor.occursAfterBraceOrSemicolon(...)
    Boolean occursAfterBraceOrSemicolon(CommonToken token, JList<CommonToken> tokens) {
        if (token.tokenIndex == 0) {
            return false;
        } else {
            value tokenType = token.type;
            if (tokenType==Lexer.lbrace ||
                tokenType==Lexer.rbrace ||
                tokenType==Lexer.semicolon) {
                return true;
            }

            value previousTokenType 
                    = adjust {
                        tokenIndex = token.tokenIndex - 1;
                        offset = token.startIndex;
                        tokens = tokens;
                    }.type;

            return previousTokenType==Lexer.lbrace
                || previousTokenType==Lexer.rbrace
                || previousTokenType==Lexer.semicolon;
        }
    }

    // see CeylonCompletionProcessor.adjust(...)
    CommonToken adjust(variable Integer tokenIndex, Integer offset, 
            JList<CommonToken> tokens) {
        variable CommonToken adjustedToken = tokens.get(tokenIndex);
        while (--tokenIndex >= 0,
               adjustedToken.type==Lexer.ws //ignore whitespace
            || adjustedToken.type==Lexer.eof
            || adjustedToken.startIndex==offset) { //don't consider the token to the right of the caret

            adjustedToken = tokens.get(tokenIndex);
            if (adjustedToken.type!=Lexer.ws
             && adjustedToken.type!=Lexer.eof 
             && adjustedToken.channel!=Token.hiddenChannel) { //don't adjust to a ws token
                break;
            }
        }
        return adjustedToken;
    }

    value noTypes => Collections.emptyList<Type>();
    
    Boolean isReturnType(Type t, FunctionOrValue m, Node node) {
        if (t.isSubtypeOf(m.type)) {
            return true;
        }
        
        if (is Tree.TypedDeclaration node) {
            if (is ClassOrInterface container 
                    = node.declarationModel.container) {
                value type 
                        = container.type
                            .getTypedMember(m, noTypes)
                            .type;
                if (t.isSubtypeOf(type)) {
                    return true;
                }
            }
        }
        
        return false;
    }

    Boolean noParametersFollow(CommonToken? nextToken) {
        //should we disable this, since a statement
        //can in fact begin with an LPAREN??
        return (nextToken?.type else Lexer.eof) 
                != Lexer.lparen;
        //disabled now because a declaration can
        //begin with an LBRACE (an Iterable type)
        /*&& nextToken.getType()!=CeylonLexer.LBRACE*/
    }

    Boolean isInvocationProposable(DeclarationWithProximity dwp, OL? ol,
            Integer previousTokenType, Unit unit, String prefix, Boolean inexactMatches) {
        if (is Functional dec = dwp.declaration,
            previousTokenType != Lexer.isOp,
            inexactMatches || dec.getName(unit)==prefix) {
            variable Boolean isProposable = true;

            isProposable &&= previousTokenType != Lexer.caseTypes || isLocation(ol, OL.\iof);

            variable Boolean isCorrectLocation = ol is Null;
            isCorrectLocation ||= isLocation(ol, OL.expression) && (if (is Class dec) then !dec.abstract else true);

            isCorrectLocation ||= isLocation(ol, OL.\iextends)
                    && (if (is Class dec) then (!dec.final && dec.typeParameters.empty) else false);

            isCorrectLocation ||= isLocation(ol, OL.\iextends)
                    && ModelUtil.isConstructor(dec)
                    && (if (is Class c = dec.container) then (!c.final && c.typeParameters.empty) else false);

            isCorrectLocation ||= isLocation(ol, OL.classAlias) && (dec is Class);

            isCorrectLocation ||= isLocation(ol, OL.parameterList)
                    && (if (is Function dec) then dec.annotation else false);

            isProposable &&= isCorrectLocation;
            isProposable &&= !dwp.namedArgumentList exists;
            isProposable &&= !dec.annotation
                     || (if (is Function dec)
                         then (!dec.parameterLists.empty && !dec.parameterLists.get(0).parameters.empty)
                         else true);

            return isProposable;
        }
        return false;
    }

    Boolean isProposable(DeclarationWithProximity dwp, OL? ol, Scope scope, Unit unit, Type? requiredType, Integer previousTokenType) {
        value dec = dwp.declaration;
        variable Boolean isProp = !isLocation(ol, OL.\iextends);
        isProp ||= if (is Class dec) then !dec.final else false;
        isProp ||= ModelUtil.isConstructor(dec) && (if (is Class c = dec.container) then !c.final else false);

        variable Boolean isCorrectLocation = !isLocation(ol, OL.classAlias) || dec is Class;
        isCorrectLocation &&= !isLocation(ol, OL.\isatisfies) || dec is Interface;
        isCorrectLocation &&= !isLocation(ol, OL.\iof) || dec is Class || isAnonymousClassValue(dec);
        isCorrectLocation &&= (!isLocation(ol, OL.typeArgumentList)
                                && !isLocation(ol, OL.upperBound)
                                && !isLocation(ol, OL.typeAlias)
                                && !isLocation(ol, OL.\icatch)
                              ) || dec is TypeDeclaration;
        isCorrectLocation &&= !isLocation(ol, OL.\icatch) || isExceptionType(unit, dec);
        isCorrectLocation &&= !isLocation(ol, OL.parameterList)
                                || dec is TypeDeclaration
                                || dec is Function && dec.annotation //i.e. an annotation
                                || dec is Value && dec.container == scope; //a parameter ref
        isCorrectLocation &&= !isLocation(ol, OL.\iimport) || !dwp.unimported;
        isCorrectLocation &&= !isLocation(ol, OL.\icase) || isCaseOfSwitch(requiredType, dec);//, previousTokenType);
        isCorrectLocation &&= previousTokenType != Lexer.isOp
                           && (previousTokenType != Lexer.caseTypes || isLocation(ol, OL.\iof))
                           || dec is TypeDeclaration;
        isCorrectLocation &&= !isLocation(ol, OL.typeParameterList);
        isCorrectLocation &&= !dwp.namedArgumentList exists;

        isProp &&= isCorrectLocation;
        return isProp;
    }

    Boolean isProposableBis(Node node, OL? ol, Declaration dec) {
        if (!isLocation(ol, OL.\iexists), !isLocation(ol, OL.\inonempty),
            !isLocation(ol, OL.\iis)) {
            return true;
        } else if (is Value val = dec) {
            Type type = val.type;
            if (val.variable || val.transient || val.default || val.formal || isTypeUnknown(type)) {
                return false;
            } else {
                variable Unit unit = node.unit;
                switch (ol)
                case (OL.\iexists) {
                    return unit.isOptionalType(type);
                }
                case (OL.\inonempty) {
                    return unit.isPossiblyEmptyType(type);
                }
                case (OL.\iis) {
                    return true;
                }
                else {
                    return false;
                }
            }
        } else {
            return false;
        }
    }


    Boolean isCaseOfSwitch(Type? requiredType, Declaration dec)//, Integer previousTokenType) 
            => /*previousTokenType == CeylonLexer.\iIS_OP 
                    &&*/ isTypeCaseOfSwitch(requiredType, dec)
            || /*previousTokenType == CeylonLexer.\iLPAREN
                    &&*/ isValueCaseOfSwitch(requiredType, dec);

    Boolean isDelegatableConstructor(Scope scope, Declaration dec) {
        if (ModelUtil.isConstructor(dec)) {
            Scope? container = dec.container;
            Scope? outerScope = scope.container;
            if (container is Null || outerScope is Null) {
                return false;
            }
            assert(exists outerScope);
            assert(exists container);
            if (outerScope == container) {
                return !scope.equals(dec); //local constructor
            } else {
                return if (exists id = scope.getInheritingDeclaration(dec)) 
                    then id.equals(outerScope) 
                    else false; //inherited constructor
            }
        } else if (is Class dec) {
            Scope outerScope = scope.container;
            if (is Class outerScope) {
                Type? sup = outerScope.extendedType;
                return sup?.declaration?.equals(dec) else false;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    Boolean isAnonymousClassValue(Declaration dec) 
            => if (is Value dec) 
            then (dec.typeDeclaration?.anonymous else false) 
            else false;

    Boolean isExceptionType(Unit unit, Declaration dec) 
            => if (is TypeDeclaration dec) 
            then dec.inherits(unit.exceptionDeclaration) 
            else false;

    Boolean isValueCaseOfSwitch(Type? requiredType, Declaration dec) {
        if (exists requiredType, requiredType.union) {
            for (td in requiredType.caseTypes) {
                if (isValueCaseOfSwitch(td, dec)) {
                    return true;
                }
            }
        }
        else if (is Value dec) {
            if (isAnonymousClassValue(dec)) {
                if (exists requiredType) {
                    if (dec.typeDeclaration
                           .inherits(requiredType.declaration)) {
                        return true;
                    }
                }
                else {
                    return true;
                }
            }
        }
        else if (is TypeDeclaration dec) {
            for (m in dec.members) {
                if (m is Value, 
                    isTypeCaseOfSwitch(requiredType, m)) {
                    return true;
                }
            }
        }
        return false;
    }

    Boolean isTypeCaseOfSwitch(Type? requiredType, Declaration dec) {
        if (exists requiredType, requiredType.union) {
            for (td in requiredType.caseTypes) {
                if (isTypeCaseOfSwitch(td, dec)) {
                    return true;
                }
            }
        }
        else if (is TypeDeclaration dec) {
            if (exists requiredType) {
                if (dec.inherits(requiredType.declaration)) {
                    return true;
                }
                for (m in dec.members) {
                    if (m is TypeDeclaration, 
                        isTypeCaseOfSwitch(requiredType, m)) {
                        return true;
                    }
                }
            }
            else {
                return true;
            }
        }
        return false;
    }

    Boolean definitelyRequiresType(OL? ol) {
        return isLocation(ol, OL.\isatisfies)
            || isLocation(ol, OL.\iof)
            || isLocation(ol, OL.upperBound)
            || isLocation(ol, OL.typeAlias);
    }

    Boolean isReferenceProposable(OL? ol, Declaration dec) {
        return (isLocation(ol, OL.valueRef)
                || (if (is Value dec) then dec.typeDeclaration.anonymous else true))
             && (isLocation(ol, OL.functionRef) 
                   || !dec is Function)
             && (isLocation(ol, OL.aliasRef) 
                   || !dec is TypeAlias)
             && (isLocation(ol, OL.typeParameterRef) 
                   || !dec is TypeParameter)
                //note: classes and interfaces are almost always proposable
                //      because they are legal qualifiers for other refs
             && (!isLocation(ol, OL.typeParameterRef) 
                   || dec is TypeParameter);
    }

    CommonToken? getNextToken(CompletionContext ctx, CommonToken token) {
        variable Integer i = token.tokenIndex;
        variable CommonToken? nextToken=null;
        value tokens = ctx.tokens;
        variable Boolean isHiddenChannel = true;
        
        while (isHiddenChannel) {
            if (++i<tokens.size()) {
                nextToken = tokens.get(i);
            }
            else {
                break;
            }
            
            isHiddenChannel 
                    = (nextToken?.channel else -1) 
                        == Token.hiddenChannel;
        }

        return nextToken;
    }
    
    shared Proposals getProposals(Node node,
        Scope? scope, String prefix, Boolean memberOp,
        Tree.CompilationUnit rootNode, 
        Cancellable? cancellable = null) {
        
        Unit? unit = node.unit;
        
        if (!exists unit) {
            return noProposals;
        }
        
        switch (node)
        case (is Tree.MemberLiteral) {
            if (exists mlt = node.type) {
                return if (exists type = mlt.typeModel)
                then type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                    unit, scope, prefix, 0, cancellable)
                else noProposals;
            }
        } case (is Tree.TypeLiteral) {
            if (is Tree.BaseType bt = node.type) {
                if (bt.packageQualified) {
                    return unit.\ipackage
                            .getMatchingDirectDeclarations(
                        prefix, 0, cancellable);
                }
            }
            if (exists tlt = node.type) {
                return if (exists type = tlt.typeModel)
                then type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                    unit, scope, prefix, 0, cancellable)
                else noProposals;
            }
        }
        else {}
        
        switch (node)
        case (is Tree.QualifiedMemberOrTypeExpression) {
            value type = let (pt = getPrimaryType(node))
            if (node.staticMethodReference)
            then unit.getCallableReturnType(pt)
            else pt;
            
            if (exists type, !type.unknown) {
                return type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                    unit, scope, prefix, 0, cancellable);
            }
            else {
                switch (primary = node.primary)
                case (is Tree.MemberOrTypeExpression) {
                    if (is TypeDeclaration td
                        = primary.declaration) {
                        return if (exists t = td.type)
                        then t.resolveAliases()
                                .declaration
                                .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0, cancellable)
                        else noProposals;
                    }
                    else {
                        return noProposals;
                    }
                }
                case (is Tree.Package) {
                    return unit.\ipackage
                            .getMatchingDirectDeclarations(
                        prefix, 0, cancellable);
                }
                else {
                    return noProposals;
                }
            }
        }
        case (is Tree.QualifiedType) {
            if (exists qt = node.outerType.typeModel) {
                return qt.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                    unit, scope, prefix, 0, cancellable);
            }
            else {
                return noProposals;
            }
        }
        case (is Tree.BaseType) {
            if (node.packageQualified) {
                return unit.\ipackage
                        .getMatchingDirectDeclarations(
                    prefix, 0, cancellable);
            }
            else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0, cancellable);
            }
            else {
                return noProposals;
            }
        }
        else {
            if (memberOp, is Tree.Term|Tree.DocLink node) {
                value type = switch (node)
                case (is Tree.Term)
                node.typeModel
                case (is Tree.DocLink)
                docLinkType(node);
                if (exists type) {
                    return type.resolveAliases()
                            .declaration
                            .getMatchingMemberDeclarations(
                        unit, scope, prefix, 0, cancellable);
                }
                else if (exists scope) {
                    return scope.getMatchingDeclarations(
                        unit, prefix, 0, cancellable);
                }
                else {
                    return noProposals;
                }
            }
            else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0, cancellable);
            }
            else {
                return getUnparsedProposals(
                    rootNode, prefix, cancellable);
            }
        }
    }
    
    Type? getPrimaryType(
        Tree.QualifiedMemberOrTypeExpression qme) {
        if (exists type = qme.primary.typeModel) {
            value unit = qme.unit;
            return switch (mo = qme.memberOperator)
            case (is Tree.SafeMemberOp)
            unit.getDefiniteType(type)
            case (is Tree.SpreadOp)
            unit.getIteratedType(type)
            else type;
        }
        else {
            return null;
        }
    }
    
    Type? docLinkType(Tree.DocLink node) 
            => if (exists base = node.base) 
                then (resultType(base)
                else base.reference.fullType) else null;
    
    Type? resultType(Declaration declaration) {
        switch (declaration)
        case (is TypedDeclaration) {
            return declaration.type;
        }
        case (is TypeDeclaration) {
            if (is Class declaration) {
                if (!declaration.abstract) {
                    return declaration.type;
                }
            }
            return null;
        }
        else {
            return null;
        }
    }
    
    Proposals getUnparsedProposals(Node? node, String prefix, 
        Cancellable? cancellable)
            => if (exists node, 
                    exists unit = node.unit,
                    exists pkg = unit.\ipackage)
                then pkg.\imodule
                    .getAvailableDeclarations(unit, 
                        prefix, 0, cancellable)
                else noProposals;
}

class FindScopeVisitor(Node node) extends Visitor() {
    variable Scope? myScope = null;

    shared Scope? scope => myScope else node.scope;

    shared actual void visit(Tree.Declaration that) {
        super.visit(that);

        if (exists al = that.annotationList) {
            for (ann in al.annotations) {
                if (ann.primary.startIndex==node.startIndex) {
                    myScope = that.declarationModel.scope;
                }
            }
        }
    }

    shared actual void visit(Tree.DocLink that) {
        super.visit(that);

        if (is Tree.DocLink node) {
            myScope = node.pkg;
        }
    }
}
