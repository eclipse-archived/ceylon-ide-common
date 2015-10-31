import ceylon.collection {
    ArrayList,
    MutableList
}
import ceylon.interop.java {
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    OccurrenceLocation,
    types,
    escaping,
    ProgressMonitor,
    Indents,
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
    Package
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
    JIterator=Iterator,
    TreeSet,
    Set
}
import java.util.regex {
    Pattern
}

import org.antlr.runtime {
    CommonToken,
    Token
}

shared abstract class IdeCompletionManager<IdeComponent,IdeArtifact,CompletionResult,Document>()
        satisfies InvocationCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & ParametersCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & KeywordCompletion<CompletionResult>
                & MemberNameCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & BasicCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & RefinementCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & PackageCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & TypeArgumentListCompletions<IdeComponent,IdeArtifact,CompletionResult,Document>
                & ModuleCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & FunctionCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
                & ControlStructureCompletionProposal<IdeComponent,IdeArtifact,CompletionResult,Document>
                & TypeCompletion<CompletionResult,Document>
                & AnonFunctionCompletion<CompletionResult>
        given CompletionResult satisfies Object
        given IdeComponent satisfies LocalAnalysisResult<Document, IdeArtifact>
        given IdeArtifact satisfies Object {

    shared alias Proposals
            => Map<JString,DeclarationWithProximity>;

    Proposals noProposals
            = HashMap<JString,DeclarationWithProximity>();

    shared formal String getDocumentSubstring(Document doc, Integer start, Integer length);
    
    shared formal Indents<Document> indents;

    // see CeylonCompletionProcessor.getContentProposals(CeylonParseController, int, ITextViewer, boolean, boolean, IProgressMonitor)
    shared CompletionResult[] getContentProposals(Tree.CompilationUnit typecheckedRootNode, IdeComponent analysisResult, 
            Integer offset, Integer line, Boolean secondLevel, ProgressMonitor monitor, Boolean returnedParamInfo = false) {
        value tokens = analysisResult.tokens;
        value document = analysisResult.document;

        // TODO perhaps we should make it non optional in LocalAnalysisResult?
        assert(exists tokens);
        
        //adjust the token to account for unclosed blocks
        //we search for the first non-whitespace/non-comment
        //token to the left of the caret
        variable Integer tokenIndex = nodes.getTokenIndexAtCharacter(tokens, offset);
        if (tokenIndex < 0) {
            tokenIndex = -tokenIndex;
        }
        CommonToken adjustedToken = adjust(tokenIndex, offset, tokens);
        Integer tt = adjustedToken.type;
        
        if (offset <= adjustedToken.stopIndex,
                offset > adjustedToken.startIndex,
                isCommentOrCodeStringLiteral(adjustedToken)) {
            return [];
        }
        if (isLineComment(adjustedToken),
                offset > adjustedToken.startIndex,
                adjustedToken.line == line + 1) {
            return [];
        }

        //find the node at the token
        Node node = getTokenNode(adjustedToken.startIndex, 
            adjustedToken.stopIndex + 1, 
            tt, typecheckedRootNode, offset);

        //it's useful to know the type of the preceding token, if any
        variable Integer index = adjustedToken.tokenIndex;
        if (offset <= adjustedToken.stopIndex+1, offset > adjustedToken.startIndex) {
            index--;
        }
        Integer tokenType = adjustedToken.type;
        Integer previousTokenType = if (index >= 0) then adjust(index, offset, tokens).type else -1;

        //find the type that is expected in the current
        //location so we can prioritize proposals of that
        //type
        //TODO: this breaks as soon as the user starts typing
        //      an expression, since RequiredTypeVisitor
        //      doesn't know how to search up the tree for
        //      the containing InvocationExpression
        value required = types.getRequiredType(typecheckedRootNode, node, adjustedToken);
        variable String prefix = "";
        variable String fullPrefix = "";
        if (isIdentifierOrKeyword(adjustedToken)) {
            String text = adjustedToken.text;
            //work from the end of the token to
            //compute the offset, in order to
            //account for quoted identifiers, where
            //the \i or \I is not in the token text 
            Integer offsetInToken = offset - adjustedToken.stopIndex - 1 + text.size;
            Integer realOffsetInToken = offset - adjustedToken.startIndex;
            if (offsetInToken <= text.size) {
                prefix = text.spanTo(offsetInToken - 1);
                fullPrefix = getRealText(adjustedToken).spanTo(realOffsetInToken - 1);
            }
        }
        variable Boolean isMemberOp = isMemberOperator(adjustedToken);
        variable String qualified = "";
        
        // special handling for doc links
        Boolean inDoc = isAnnotationStringLiteral(adjustedToken)
                && offset>adjustedToken.startIndex
                && offset<=adjustedToken.stopIndex;
        if (inDoc) {
            if (is Tree.DocLink node) {
                Tree.DocLink docLink = node;
                Integer offsetInLink = offset - docLink.startIndex.intValue();
                String text = docLink.token.text;
                Integer bar = (text.firstOccurrence('|') else -1) + 1;
                if (offsetInLink < bar) { 
                    return [];
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
                return [];
            }
        }
        
        FindScopeVisitor fsv = FindScopeVisitor(node);
        fsv.visit(typecheckedRootNode);
        Scope? scope = fsv.scope;

        // I think the rest of this function assumes the scope always exists
        if (!exists scope) {
            return [];
        }
        
        //construct completions when outside ordinary code
        value completions = 
                constructCompletionsOutsideOrdinaryCode(offset, fullPrefix, 
                        analysisResult, node, adjustedToken,
                        scope, returnedParamInfo, isMemberOp,
                        tokenType, monitor);
        
        if (exists completions) {
            return completions; 
        }
        else {
            Proposals proposals = getProposals(node, scope, prefix, isMemberOp, typecheckedRootNode);
            Proposals functionProposals = getFunctionProposals(node, scope, prefix, isMemberOp);
            filterProposals(proposals);
            filterProposals(functionProposals);
            value sortedProposals = sortProposals(prefix, required, proposals);
            value sortedFunctionProposals = sortProposals(prefix, required, functionProposals);
            return constructCompletions(offset, if (inDoc) then qualified else fullPrefix, sortedProposals,
                sortedFunctionProposals, analysisResult, scope, node, adjustedToken, isMemberOp, document,
                secondLevel, inDoc, required.type, previousTokenType, tokenType);
        }
    }
    
    CompletionResult[]? constructCompletionsOutsideOrdinaryCode(Integer offset, String prefix, IdeComponent cpc,
            Node node, CommonToken token, Scope scope, Boolean returnedParamInfo, Boolean memberOp,
            Integer tokenType, ProgressMonitor monitor) {
        value result = ArrayList<CompletionResult>();

        if (!returnedParamInfo, atStartOfPositionalArgument(node, token)) {
            addFakeShowParametersCompletion(node, cpc, result);
            if (result.empty) {
                return null;
            }
        } else if (is Tree.PackageLiteral node) {
            addPackageCompletions(cpc, offset, prefix, null, node, result, false, monitor);
        } else if (is Tree.ModuleLiteral node) {
            addModuleCompletions(cpc, offset, prefix, null, node, result, false, monitor);
        } else if (isDescriptorPackageNameMissing(node)) {
            addCurrentPackageNameCompletion(cpc, offset, prefix, result);
        } else if (node is Tree.Import, offset > token.stopIndex+1) {
            addPackageCompletions(cpc, offset, prefix, null, node, result, nextTokenType(cpc, token) != CeylonLexer.\iLBRACE, monitor);
        } else if (node is Tree.ImportModule, offset > token.stopIndex+1) {
            addModuleCompletions(cpc, offset, prefix, null, node, result, nextTokenType(cpc, token) != CeylonLexer.\iSTRING_LITERAL, monitor);
        } else if (is Tree.ImportPath node) {
            ImportVisitor(prefix, token, offset, node, cpc, result, monitor, this).visit(cpc.lastCompilationUnit);
        } else if (isEmptyModuleDescriptor(cpc.lastCompilationUnit)) {
            addModuleDescriptorCompletion(cpc, offset, prefix, result);
            addKeywordProposals(cpc.lastCompilationUnit, offset, prefix, result, node, null, false, tokenType);
        } else if (isEmptyPackageDescriptor(cpc.lastCompilationUnit)) {
            addPackageDescriptorCompletion(cpc, offset, prefix, result);
            addKeywordProposals(cpc.lastCompilationUnit, offset, prefix, result, node, null, false, tokenType);
        } else if (node is Tree.TypeArgumentList, token.type == CeylonLexer.\iLARGER_OP) {
            if (offset == token.stopIndex+1) {
                addTypeArgumentListProposal(offset, cpc, node, scope, result, this);
            } else if (isMemberNameProposable(offset, node, memberOp)) {
                addMemberNameProposals(offset, cpc, node, result);
            } else {
                return null;
            }
        } else {
            return null;
        }
        return result.sequence();
    }

    Boolean isDescriptorPackageNameMissing(Node node) {
        Tree.ImportPath? path;
        if (is Tree.ModuleDescriptor node) {
            path = node.importPath;
        } else if (is Tree.PackageDescriptor node) {
            path = node.importPath;
        } else {
            return false;
        }
        return path?.identifiers?.empty else true;
    }


    Boolean atStartOfPositionalArgument(Node node, CommonToken token) {
        if (is Tree.PositionalArgumentList node) {
            variable Integer type = token.type;
            return type == CeylonLexer.\iLPAREN || type == CeylonLexer.\iCOMMA;
        } else if (is Tree.NamedArgumentList node) {
            variable Integer type = token.type;
            return type == CeylonLexer.\iLBRACE || type == CeylonLexer.\iSEMICOLON;
        } else {
            return false;
        }
    }

    // see CeylonCompletionProcessor.
    void filterProposals(Proposals proposals) {
        List<Pattern> filters = proposalFilters;
        if (!filters.empty) {
            JIterator<DeclarationWithProximity> iterator = proposals.values().iterator();
            while (iterator.hasNext()) {
                DeclarationWithProximity dwp = iterator.next();
                String name = dwp.declaration.qualifiedNameString;
                for (Pattern filter in filters) {
                    if (filter.matcher(javaString(name)).matches()) {
                        iterator.remove();
                    }
                }
            }
        }
    }

    shared formal List<Pattern> proposalFilters;
    
    // see CeylonCompletionProcessor.sortProposals()
    Set<DeclarationWithProximity> sortProposals(String prefix, RequiredType required, Proposals proposals) {
        Set<DeclarationWithProximity> set = TreeSet<DeclarationWithProximity>(ProposalComparator(prefix, required));
        set.addAll(proposals.values());
        return set;
    }

    // see CeylonCompletionProcessor.isAnnotationStringLiteral()
    Boolean isAnnotationStringLiteral(CommonToken token) {
        Integer type = token.type;
        return type == CeylonLexer.\iASTRING_LITERAL
                || type == CeylonLexer.\iAVERBATIM_STRING;
    }

    // see CeylonCompletionProcessor.isMemberOperator()
    Boolean isMemberOperator(Token token) {
        Integer type = token.type;
        return type == CeylonLexer.\iMEMBER_OP 
                || type == CeylonLexer.\iSPREAD_OP 
                || type == CeylonLexer.\iSAFE_MEMBER_OP;
    }
    
    // see CeylonCompletionProcessor.getRealText()
    String getRealText(CommonToken token) {
        String text = token.text;
        Integer type = token.type;
        Integer len = token.stopIndex - token.startIndex + 1;
        if (text.size < len) {
            variable String quote;
            if (type == CeylonLexer.\iLIDENTIFIER) {
                quote = "\\i";
            } else if (type == CeylonLexer.\iUIDENTIFIER) {
                quote = "\\I";
            } else {
                quote = "";
            }
            return quote + text;
        } else {
            return text;
        }
    }

    // see CeylonCompletionProcessor.getTokenNode()
    Node getTokenNode(Integer adjustedStart, Integer adjustedEnd, Integer tokenType, Tree.CompilationUnit rootNode, Integer offset) {
        variable Node? node = nodes.findNode(rootNode, null, adjustedStart, adjustedEnd);
        if (is Tree.StringLiteral sl = node, !sl.docLinks.empty) {
            node = nodes.findNode(sl, null, offset, offset);
        }
        if (tokenType == CeylonLexer.\iRBRACE && !(node is Tree.IterableType)
                || tokenType == CeylonLexer.\iSEMICOLON) {
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
        return type == CeylonLexer.\iLIDENTIFIER
                || type == CeylonLexer.\iUIDENTIFIER 
                || type == CeylonLexer.\iAIDENTIFIER 
                || type == CeylonLexer.\iPIDENTIFIER 
                || escaping.keywords.contains(token.text);
    }

    // see CeylonCompletionProcessor.isCommentOrCodeStringLiteral()
    Boolean isCommentOrCodeStringLiteral(CommonToken adjustedToken) {
        Integer tt = adjustedToken.type;
        return tt == CeylonLexer.\iMULTI_COMMENT
                || tt == CeylonLexer.\iLINE_COMMENT 
                || tt == CeylonLexer.\iSTRING_LITERAL 
                || tt == CeylonLexer.\iSTRING_END 
                || tt == CeylonLexer.\iSTRING_MID 
                || tt == CeylonLexer.\iSTRING_START 
                || tt == CeylonLexer.\iVERBATIM_STRING 
                || tt == CeylonLexer.\iCHAR_LITERAL 
                || tt == CeylonLexer.\iFLOAT_LITERAL 
                || tt == CeylonLexer.\iNATURAL_LITERAL;
    }
    
    // see CeylonCompletionProcessor.isLineComment()
    Boolean isLineComment(variable CommonToken adjustedToken) {
        return adjustedToken.type == CeylonLexer.\iLINE_COMMENT;
    }

    shared Proposals getProposals(Node node,
            Scope? scope, String prefix, Boolean memberOp,
            Tree.CompilationUnit rootNode) {

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
                            unit, scope, prefix, 0)
                    else noProposals;
            }
        } case (is Tree.TypeLiteral) {
            if (is Tree.BaseType bt = node.type) {
                if (bt.packageQualified) {
                    return unit.\ipackage
                        .getMatchingDirectDeclarations(
                            prefix, 0);
                }
            }
            if (exists tlt = node.type) {
                return if (exists type = tlt.typeModel)
                    then type.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0)
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
                            unit, scope, prefix, 0);
            } else {
                switch (primary = node.primary)
                case (is Tree.MemberOrTypeExpression) {
                    if (is TypeDeclaration td
                            = primary.declaration) {
                        return if (exists t = td.type)
                            then t.resolveAliases()
                                .declaration
                                .getMatchingMemberDeclarations(
                                    unit, scope, prefix, 0)
                            else noProposals;
                    } else {
                        return noProposals;
                    }
                } case (is Tree.Package) {
                    return unit.\ipackage
                            .getMatchingDirectDeclarations(
                                prefix, 0);
                } else {
                    return noProposals;
                }
            }
        } case (is Tree.QualifiedType) {
            if (exists qt = node.outerType.typeModel) {
                return qt.resolveAliases()
                        .declaration
                        .getMatchingMemberDeclarations(
                            unit, scope, prefix, 0);
            } else {
                return noProposals;
            }
        } case (is Tree.BaseType) {
            if (node.packageQualified) {
                return unit.\ipackage
                        .getMatchingDirectDeclarations(
                            prefix, 0);
            } else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0);
            } else {
                return noProposals;
            }
        } else {
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
                                unit, scope, prefix, 0);
                } else if (exists scope) {
                    return scope.getMatchingDeclarations(
                        unit, prefix, 0);
                } else {
                    return noProposals;
                }
            } else if (exists scope) {
                return scope.getMatchingDeclarations(
                    unit, prefix, 0);
            }
            else {
                return getUnparsedProposals(
                    rootNode, prefix);
            }
        }
    }

    Type? getFunctionProposalType(Node node,
            Boolean memberOp) {
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
            Scope scope, String prefix, Boolean memberOp)
            => if (exists type
                    = getFunctionProposalType(node, memberOp),
                    !isTypeUnknown(type))
            then collectUnaryFunctions(type,
                scope.getMatchingDeclarations(node.unit,
                    prefix, 0))
            else noProposals;

    Proposals collectUnaryFunctions(Type type,
            Proposals candidates) {
        value matches
                = HashMap<JString,DeclarationWithProximity>();

        CeylonIterable(candidates.entrySet())
                .each(void (candidate) {
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

                    Type? t = params.get(0).type;
                    if (unary,
                            !isTypeUnknown(t),
                            type.isSubtypeOf(t)) {
                        matches.put(candidate.key,
                            candidate.\ivalue);
                    }
                }
            }
        });

        return matches;
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

    Type? docLinkType(Tree.DocLink node) {
        if (exists base = node.base) {
            return resultType(base)
                else base.reference.fullType;
        }
        else {
            return null;
        }
    }

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

    Proposals getUnparsedProposals(Node? node, String prefix)
            => if (exists node,
                    exists pkg = node.unit?.\ipackage)
                then pkg.\imodule
                    .getAvailableDeclarations(prefix, 0)
                else noProposals;

    shared Boolean isQualifiedType(Node node)
            => if (is Tree.QualifiedMemberOrTypeExpression node)
                then node.staticMethodReference
                else node is Tree.QualifiedType;

    // see CeylonCompletionProcess.constructCompletions(...)
    shared CompletionResult[] constructCompletions(Integer offset, String prefix,
            Collection<DeclarationWithProximity> sortedProposals,
            Collection<DeclarationWithProximity> sortedFunctionProposals,
            IdeComponent cmp, Scope scope,
            Node node, CommonToken token,
            Boolean memberOp, Document doc,
            Boolean secondLevel, Boolean inDoc,
            Type? requiredType, Integer previousTokenType,
            Integer tokenType) {

        value result = ArrayList<CompletionResult>();
        value cu = cmp.lastCompilationUnit;
        value ol = nodes.getOccurrenceLocation(cu, node, offset);
        value unit = node.unit;
        value addParameterTypesInCompletions = cmp.options.parameterTypesInCompletion;

        if (is Tree.Term node) {
            addParametersProposal(offset, prefix, node, result, cmp);
        } else if (is Tree.ArgumentList node) {
            value fiv = FindInvocationVisitor(node);
            (fiv of Visitor).visit(cu);

            if (exists ie = fiv.result) {
                addParametersProposal(offset, prefix, ie, result, cmp);
            }
        }

        if (is Tree.TypeConstraint node) {
            for (dwp in CeylonIterable(sortedProposals)) {
                value dec = dwp.declaration;
                if (isTypeParameterOfCurrentDeclaration(node, dec)) {
                    addReferenceProposal(cu, offset, prefix, cmp,
                        result, dwp, null, scope, ol, false);
                }
            }
        } else if (prefix.empty, !isLocation(ol, OccurrenceLocation.\iIS),
                isMemberNameProposable(offset, node, memberOp),
                node is Tree.Type || node is Tree.BaseTypeExpression || node is Tree.QualifiedTypeExpression) {
            
            //member names we can refine
            Type? t = switch (node)
                case (is Tree.Type) node.typeModel
                case (is Tree.BaseTypeExpression) node.target?.type
                case (is Tree.QualifiedTypeExpression) node.target?.type
                else null;

            if (exists t) {
                addRefinementProposals(offset,
                        sortedProposals, cmp, scope, node, doc,
                        secondLevel, result, ol, t, false);
            }
            //otherwise guess something from the type
            addMemberNameProposal(offset, prefix, node, result, cu);
        } else if (is Tree.TypedDeclaration node, 
            !(node is Tree.Variable && node.type is Tree.SyntheticVariable),
            //!(node is Tree.InitializerParameter),
            isMemberNameProposable(offset, node, memberOp)) {
            
            //member names we can refine
            if (exists dnt = node.type, exists t = dnt.typeModel) {
                addRefinementProposals(offset, sortedProposals, 
                        cmp, scope, node, doc, secondLevel, 
                        result, ol, t, true);
            }
            //otherwise guess something from the type
            addMemberNameProposal(offset, prefix, node, result, cu);
        } else {
            value isMember = if (is Tree.MemberLiteral node)
                then node.type exists
                else node is Tree.QualifiedMemberOrTypeExpression || node is Tree.QualifiedType;

            if (!secondLevel, !inDoc, !memberOp) {
                addKeywordProposals(cmp.lastCompilationUnit, offset, prefix, result, node, ol, isMember, tokenType);
            }
            if (!secondLevel, !inDoc, !isMember,
                    prefix.empty, !ModelUtil.isTypeUnknown(requiredType), unit.isCallableType(requiredType)) {
                addAnonFunctionProposal(offset, requiredType, result, unit);
            }

            value isPackageOrModuleDescriptor = isModuleDescriptor(cu) || isPackageDescriptor(cu);

            for (dwp in CeylonIterable(sortedProposals)) {
                value dec = dwp.declaration;

                if (!dec.toplevel, !dec.classOrInterfaceMember, dec.unit == unit) {
                    if (exists decNode = nodes.getReferencedNodeInUnit(dec, cu),
                            exists id = nodes.getIdentifyingNode(decNode), 
                            offset < id.startIndex.intValue()) {
                        continue;
                    }
                }

                if (isPackageOrModuleDescriptor, !inDoc, !isLocation(ol, OccurrenceLocation.\iMETA),
                    !(ol?.reference else false),
                    !dec.annotation || !(dec is Function)) {
                    continue;
                }

                if (!secondLevel,
                        isParameterOfNamedArgInvocation(scope, dwp),
                        isDirectlyInsideNamedArgumentList(cmp, node, token)) {
                    addNamedArgumentProposal(offset, prefix, cmp, 
                        result, dec, scope);
                    addInlineFunctionProposal(offset, dec, scope,
                        node, prefix, cmp, doc, result, indents);
                }

                value nextToken = getNextToken(cmp, token);
                value noParamsFollow = noParametersFollow(nextToken);

                if (!secondLevel, !inDoc, noParamsFollow, isInvocationProposable(dwp, ol, previousTokenType),
                        !isQualifiedType(node) || ModelUtil.isConstructor(dec) || dec.staticallyImportable,
                        if (is Constructor scope)
                        then !isLocation(ol, OccurrenceLocation.\iEXTENDS) || isDelegatableConstructor(scope, dec)
                        else true) {
                    for (d in overloads(dec)) {
                        value pr = if (isMember)
                            then getQualifiedProducedReference(node, dec)
                            else getRefinedProducedReference(scope, dec);

                        addInvocationProposals(offset, prefix, cmp, result, dwp, dec, pr, scope, ol, null, isMember);
                    }
                }
                if (isProposable(dwp, ol, scope, unit, requiredType, previousTokenType),
                    isProposableBis(node, ol, dec),
                    (definitelyRequiresType(ol) || noParamsFollow || dec is Functional),
                    (!scope is Constructor || !isLocation(ol, OccurrenceLocation.\iEXTENDS) || isDelegatableConstructor(scope, dec))) {

                    if (isLocation(ol, OccurrenceLocation.\iDOCLINK)) {
                        addDocLinkProposal(offset, prefix, cmp, result, dec, scope);
                    } else if (isLocation(ol, OccurrenceLocation.\iIMPORT)) {
                        addImportProposal(offset, prefix, cmp, result, dec, scope);
                    } else if (ol?.reference else false) {
                        if (isReferenceProposable(ol, dec)) {
                            addProgramElementReferenceProposal(offset, prefix, cmp, result, dec, scope, isMember);
                        }
                    } else {
                        value pr = if (isMember)
                            then getQualifiedProducedReference(node, dec)
                            else getRefinedProducedReference(scope, dec);

                        if (secondLevel, exists pr) {
                            addSecondLevelProposal(offset, prefix, cmp, result, dec, scope, false, pr, requiredType, ol);
                        } else if (!dec is Function || !ModelUtil.isAbstraction(dec) || !noParamsFollow) {
                            addReferenceProposal(cu, offset, prefix, cmp, result, dwp, pr, scope, ol, isMember);
                        }
                    }
                }

                if (!memberOp, !secondLevel, isProposable(dwp, ol, scope, unit, requiredType, previousTokenType), 
                        !isLocation(ol, OccurrenceLocation.\iIMPORT),
                        !isLocation(ol, OccurrenceLocation.\iCASE),
                        !isLocation(ol, OccurrenceLocation.\iCATCH),
                        isDirectlyInsideBlock(node, cmp, scope, token)) {
                    
                    addForProposal(offset, prefix, cmp, result, dwp, dec);
                    addIfExistsProposal(offset, prefix, cmp, result, dwp, dec);
                    addAssertExistsProposal(offset, prefix, cmp, result, dwp, dec);
                    addIfNonemptyProposal(offset, prefix, cmp, result, dwp, dec);
                    addAssertNonemptyProposal(offset, prefix, cmp, result, dwp, dec);
                    addTryProposal(offset, prefix, cmp, result, dwp, dec);
                    addSwitchProposal(offset, prefix, cmp, result, dwp, dec, node, indents);
                }
                
                if (!memberOp, !isMember, !secondLevel) {
                    for (d in overloads(dec)) {
                        if (isRefinementProposable(d, ol, scope), is ClassOrInterface scope) {
                            addRefinementProposal(offset, d, scope, node, scope, prefix, cmp, result,
                                true, indents, addParameterTypesInCompletions);
                        }
                    }
                }
            }
        }

        if (node is Tree.QualifiedMemberExpression 
            || memberOp && node is Tree.QualifiedTypeExpression) {
            
            assert(is Tree.QualifiedMemberOrTypeExpression node);
            
            for (dwp in CeylonIterable(sortedFunctionProposals)) {
                value primary = node.primary;
                addFunctionProposal(offset, cmp, primary, result, dwp.declaration, this);
            }
        }
        if (previousTokenType==CeylonLexer.\iOBJECT_DEFINITION) {
            addKeywordProposals(cu, offset, prefix, 
                result, node, ol, false, tokenType);
        }

        return result.sequence();
    }

    Boolean isDirectlyInsideBlock(Node node, IdeComponent cpc, Scope scope, CommonToken token) {
        if (scope is Interface || scope is Package) {
            return false;
        } else {
            assert(exists tokens = cpc.tokens);
            return !(node is Tree.SequenceEnumeration) && occursAfterBraceOrSemicolon(token, tokens);
        }
    }

    // see CeylonParseController.isMemberNameProposable(int offset, Node node, boolean memberOp)
    Boolean isMemberNameProposable(Integer offset,
        Node node, Boolean memberOp) {
        Token? token = node.endToken;
        return if(is CommonToken token, !memberOp,
            token.stopIndex >= offset-2) then true else false;
    }

    Reference? getQualifiedProducedReference(Node node, Declaration d) {
        variable Type? pt;

        if (is Tree.QualifiedMemberOrTypeExpression node) {
            pt = node.primary.typeModel;
        } else if (is Tree.QualifiedType node) {
            pt = node.outerType.typeModel;
        } else {
            return null;
        }

        if (exists p = pt, d.classOrInterfaceMember, is TypeDeclaration container = d.container) {
            pt = p.getSupertype(container);
        }

        return d.appliedReference(pt, Collections.emptyList<Type>());
    }

    Reference? getRefinedProducedReference(Type|Scope typeOrScope, Declaration d) {
        if (is Type typeOrScope) {
            value superType = typeOrScope;
            if (superType.intersection) {
                for (pt in CeylonIterable(superType.satisfiedTypes)) {
                    Reference? result = getRefinedProducedReference(pt, d);
                    if (exists result) {
                        return result;
                    }
                }
                return null; //never happens?
            }
            else {
                if (exists declaringType = superType.declaration.getDeclaringType(d)) {
                    Type outerType = superType.getSupertype(declaringType.declaration);
                    return refinedProducedReference(outerType, d);
                }
                return null;
            }
        } else {
            Type? outerType = typeOrScope.getDeclaringType(d);
            JList<Type> params = JArrayList<Type>();
            if (is Generic d) {
                CeylonIterable(d.typeParameters).each(void (tp) => params.add(tp.type));
            }
            return d.appliedReference(outerType, params);
        }
    }

    Reference refinedProducedReference(Type outerType, Declaration d) {
        JList<Type> params = JArrayList<Type>();
        if (is Generic d) {
            for (tp in CeylonIterable(d.typeParameters)) {
                params.add(tp.type);
            }
        }
        return d.appliedReference(outerType, params);
    }

    Boolean isTypeParameterOfCurrentDeclaration(Node node, Declaration d) {
        //TODO: this is a total mess and totally error-prone
        //       - figure out something better!
        if (is TypeParameter tp = d) {
            Scope tpc = tp.container;
            if (tpc==node.scope) {
                return true;
            }
            else if (is Tree.TypeConstraint constraint = node){
                return if (exists tcp = constraint.declarationModel, tpc==tcp.container) then true else false;
            }
        }

        return false;
    }

    void addRefinementProposals(Integer offset,
        Collection<DeclarationWithProximity> set,
        IdeComponent cpc, Scope scope,
        Node node, Document doc, Boolean filter,
        MutableList<CompletionResult> result,
        OccurrenceLocation? ol, Type t,
        Boolean preamble) {

        value addParameterTypesInCompletions = cpc.options.parameterTypesInCompletion;
        
        for (dwp in CeylonIterable(set)) {
            value dec = dwp.declaration;
            if (!filter, is FunctionOrValue m = dec) {
                for (d in overloads(dec)) {
                    if (isRefinementProposable(d, ol, scope),
                        isReturnType(t, m, node), is ClassOrInterface scope) {
                        value start = node.startIndex.intValue();
                        String pfx = getDocumentSubstring(doc, 0, offset - start);

                        addRefinementProposal(offset, d, scope, node, scope, pfx, cpc,
                            result, preamble, indents, addParameterTypesInCompletions);
                    }
                }
            }
        }
    }

    Boolean isRefinementProposable(Declaration dec, OccurrenceLocation? ol, Scope scope) {
        return ol is Null &&
                (dec.default || dec.formal) &&
                (dec is FunctionOrValue || dec is Class) &&
                (if (is ClassOrInterface scope) then scope.isInheritedFromSupertype(dec) else false);
    }

    Boolean isParameterOfNamedArgInvocation(Scope scope, DeclarationWithProximity d) {
        return if (exists nal = d.namedArgumentList, scope == nal) then true else false;
    }

    Boolean isDirectlyInsideNamedArgumentList(IdeComponent cmp, Node node, CommonToken token) {
        assert(exists tokens = cmp.tokens);
        return node is Tree.NamedArgumentList ||
                (!(node is Tree.SequenceEnumeration) &&
            occursAfterBraceOrSemicolon(token, tokens));
    }

    // see CeylonCompletionProcessor.occursAfterBraceOrSemicolon(...)
    Boolean occursAfterBraceOrSemicolon(CommonToken token, JList<CommonToken> tokens) {
        if (token.tokenIndex == 0) {
            return false;
        } else {
            value tokenType = token.type;
            if (tokenType==CeylonLexer.\iLBRACE ||
                tokenType==CeylonLexer.\iRBRACE ||
                    tokenType==CeylonLexer.\iSEMICOLON) {
                return true;
            }

            value previousTokenType = adjust(token.tokenIndex - 1,
                token.startIndex, tokens).type;

            return previousTokenType==CeylonLexer.\iLBRACE ||
                    previousTokenType==CeylonLexer.\iRBRACE ||
                    previousTokenType==CeylonLexer.\iSEMICOLON;
        }
    }

    // see CeylonCompletionProcessor.adjust(...)
    CommonToken adjust(variable Integer tokenIndex, Integer offset, JList<CommonToken> tokens) {
        variable CommonToken adjustedToken = tokens.get(tokenIndex);
        while (--tokenIndex >= 0,
               adjustedToken.type==CeylonLexer.\iWS //ignore whitespace
            || adjustedToken.type==CeylonLexer.\iEOF
            || adjustedToken.startIndex==offset) { //don't consider the token to the right of the caret

            adjustedToken = tokens.get(tokenIndex);
            if (adjustedToken.type!=CeylonLexer.\iWS &&
                        adjustedToken.type!=CeylonLexer.\iEOF &&
                        adjustedToken.channel!=Token.\iHIDDEN_CHANNEL) { //don't adjust to a ws token
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
            value td = node;
            value container = td.declarationModel.container;
            if (is ClassOrInterface container) {
                value ci = container;
                value type = ci.type.getTypedMember(m, noTypes).type;
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
        return (nextToken?.type else CeylonLexer.\iEOF) != CeylonLexer.\iLPAREN;
        //disabled now because a declaration can
        //begin with an LBRACE (an Iterable type)
        /*&& nextToken.getType()!=CeylonLexer.LBRACE*/
    }

    Boolean isInvocationProposable(DeclarationWithProximity dwp, OccurrenceLocation? ol, Integer previousTokenType) {
        if (is Functional dec = dwp.declaration, previousTokenType != CeylonLexer.\iIS_OP) {
            variable Boolean isProposable = true;

            isProposable &&= previousTokenType != CeylonLexer.\iCASE_TYPES || isLocation(ol, OccurrenceLocation.\iOF);

            variable Boolean isCorrectLocation = ol is Null;
            isCorrectLocation ||= isLocation(ol, OccurrenceLocation.\iEXPRESSION) && (if (is Class dec) then !dec.abstract else true);

            isCorrectLocation ||= isLocation(ol, OccurrenceLocation.\iEXTENDS)
                    && (if (is Class dec) then (!dec.final && dec.typeParameters.empty) else false);

            isCorrectLocation ||= isLocation(ol, OccurrenceLocation.\iEXTENDS)
                    && ModelUtil.isConstructor(dec)
                    && (if (is Class c = dec.container) then (!c.final && c.typeParameters.empty) else false);

            isCorrectLocation ||= isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS) && (dec is Class);

            isCorrectLocation ||= isLocation(ol, OccurrenceLocation.\iPARAMETER_LIST)
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

    Boolean isProposable(DeclarationWithProximity dwp, OccurrenceLocation? ol, Scope scope, Unit unit, Type? requiredType, Integer previousTokenType) {
        value dec = dwp.declaration;
        variable Boolean isProp = !isLocation(ol, OccurrenceLocation.\iEXTENDS);
        isProp ||= if (is Class dec) then !dec.final else false;
        isProp ||= ModelUtil.isConstructor(dec) && (if (is Class c = dec.container) then !c.final else false);

        variable Boolean isCorrectLocation = !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS) || dec is Class;
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iSATISFIES) || dec is Interface;
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iOF) || dec is Class || isAnonymousClassValue(dec);
        isCorrectLocation &&= (!isLocation(ol, OccurrenceLocation.\iTYPE_ARGUMENT_LIST)
                                && !isLocation(ol, OccurrenceLocation.\iUPPER_BOUND)
                                && !isLocation(ol, OccurrenceLocation.\iTYPE_ALIAS)
                                && !isLocation(ol, OccurrenceLocation.\iCATCH)
                              ) || dec is TypeDeclaration;
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iCATCH) || isExceptionType(unit, dec);
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iPARAMETER_LIST)
                                || dec is TypeDeclaration
                                || dec is Function && dec.annotation //i.e. an annotation
                                || dec is Value && dec.container == scope; //a parameter ref
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iIMPORT) || !dwp.unimported;
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iCASE) || isCaseOfSwitch(requiredType, dec, previousTokenType);
        isCorrectLocation &&= previousTokenType != CeylonLexer.\iIS_OP
                           && (previousTokenType != CeylonLexer.\iCASE_TYPES || isLocation(ol, OccurrenceLocation.\iOF))
                           || dec is TypeDeclaration;
        isCorrectLocation &&= !isLocation(ol, OccurrenceLocation.\iTYPE_PARAMETER_LIST);
        isCorrectLocation &&= !dwp.namedArgumentList exists;

        isProp &&= isCorrectLocation;
        return isProp;
    }

    Boolean isProposableBis(Node node, OccurrenceLocation? ol, Declaration dec) {
        if (!isLocation(ol, OccurrenceLocation.\iEXISTS), !isLocation(ol, OccurrenceLocation.\iNONEMPTY),
            !isLocation(ol, OccurrenceLocation.\iIS)) {
            return true;
        } else if (is Value val = dec) {
            Type type = val.type;
            if (val.variable || val.transient || val.default || val.formal || isTypeUnknown(type)) {
                return false;
            } else {
                variable Unit unit = node.unit;
                switch (ol)
                case (OccurrenceLocation.\iEXISTS) {
                    return unit.isOptionalType(type);
                }
                case (OccurrenceLocation.\iNONEMPTY) {
                    return unit.isPossiblyEmptyType(type);
                }
                case (OccurrenceLocation.\iIS) {
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


    Boolean isCaseOfSwitch(Type? requiredType, Declaration dec, Integer previousTokenType) {
        return previousTokenType == CeylonLexer.\iIS_OP && isTypeCaseOfSwitch(requiredType, dec)
                || previousTokenType != CeylonLexer.\iIS_OP && isValueCaseOfSwitch(requiredType, dec);
    }

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
                TypeDeclaration? id = scope.getInheritingDeclaration(dec);
                return if (exists id) then id.equals(outerScope) else false; //inherited constructor
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
            for (td in CeylonIterable(requiredType.caseTypes)) {
                if (isValueCaseOfSwitch(td, dec)) {
                    return true;
                }
            }
            return false;
        } else {
            if (isAnonymousClassValue(dec)) {
                if (exists requiredType) {
                    assert(is TypedDeclaration d = dec);
                    TypeDeclaration td = d.typeDeclaration;
                    TypeDeclaration rtd = requiredType.declaration;
                    return td.inherits(rtd);
                } else {
                    return true;
                }
            } else {
                return false;
            }
        }
    }

    Boolean isTypeCaseOfSwitch(Type? requiredType, Declaration dec) {
        if (exists requiredType, requiredType.union) {
            for (Type td in CeylonIterable(requiredType.caseTypes)) {
                if (isTypeCaseOfSwitch(td, dec)) {
                    return true;
                }
            }
            return false;
        } else {
            if (is TypeDeclaration dec) {
                if (exists requiredType) {
                    TypeDeclaration rtd = requiredType.declaration;
                    return dec.inherits(rtd);
                } else {
                    return true;
                }
            } else {
                return false;
            }
        }
    }

    Boolean definitelyRequiresType(OccurrenceLocation? ol) {
        return isLocation(ol, OccurrenceLocation.\iSATISFIES)
                || isLocation(ol, OccurrenceLocation.\iOF)
                || isLocation(ol, OccurrenceLocation.\iUPPER_BOUND)
                || isLocation(ol, OccurrenceLocation.\iTYPE_ALIAS);
    }

    Boolean isReferenceProposable(OccurrenceLocation? ol, Declaration dec) {
        return (isLocation(ol, OccurrenceLocation.\iVALUE_REF)
                || (if (is Value dec) then dec.typeDeclaration.anonymous else true)
               )
             && (isLocation(ol, OccurrenceLocation.\iFUNCTION_REF) || !(dec is Function))
             && (isLocation(ol, OccurrenceLocation.\iALIAS_REF) || !(dec is TypeAlias))
             && (isLocation(ol, OccurrenceLocation.\iTYPE_PARAMETER_REF) || !(dec is TypeParameter))
                //note: classes and interfaces are almost always proposable
                //      because they are legal qualifiers for other refs
             && (!isLocation(ol, OccurrenceLocation.\iTYPE_PARAMETER_REF) || dec is TypeParameter);
    }

    CommonToken? getNextToken(IdeComponent cmp, CommonToken token) {
        variable Integer i = token.tokenIndex;
        variable CommonToken? nextToken=null;
        assert(exists tokens = cmp.tokens);
        variable Boolean isHiddenChannel = true;
        
        while (isHiddenChannel) {
            if (++i<tokens.size()) {
                nextToken = tokens.get(i);
            }
            else {
                break;
            }
            
            isHiddenChannel = (nextToken?.channel else -1) == Token.\iHIDDEN_CHANNEL;
        }

        return nextToken;
    }
}

shared class FindScopeVisitor(Node node) extends Visitor() {
    variable Scope? myScope = null;

    shared Scope? scope => myScope else node.scope;

    shared actual void visit(Tree.Declaration that) {
        super.visit(that);

        if (exists al = that.annotationList) {
            for (ann in CeylonIterable(al.annotations)) {
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