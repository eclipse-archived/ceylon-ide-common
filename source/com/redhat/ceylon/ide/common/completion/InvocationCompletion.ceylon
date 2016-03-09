import ceylon.collection {
    MutableList,
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Reference,
    Scope,
    Functional,
    TypeDeclaration,
    Generic,
    Unit,
    Class,
    Interface,
    Type,
    ModelUtil,
    FunctionOrValue,
    ParameterList,
    Parameter,
    TypeParameter,
    DeclarationWithProximity,
    Module,
    Value,
    Function,
    NothingType
}

import java.util {
    Collections,
    HashSet,
    JList=List
}

shared interface InvocationCompletion<IdeComponent,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document> {
    
    shared formal CompletionResult newInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, IdeComponent cmp,
        Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation, 
        Boolean inheritance, Boolean qualified, Declaration? qualifyingDec);
    
    shared formal CompletionResult newParameterInfo(Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, IdeComponent cpc, Boolean namedInvocation);
    
    shared void addProgramElementReferenceProposal(Integer offset, String prefix,
        IdeComponent cpc, MutableList<CompletionResult> result,
        Declaration dec, Scope scope, Boolean isMember) {
        
        Unit? unit = cpc.lastCompilationUnit.unit;
        value name = dec.getName(unit);
        value desc = escaping.escapeName(dec, unit);
        result.add(newInvocationCompletion(offset, prefix, 
            name, desc, dec, dec.reference, scope, cpc, true, 
            false, false, false, isMember, null));
    }    

    // see InvocationCompletionProposal.addReferenceProposal()
    shared void addReferenceProposal(Tree.CompilationUnit cu,
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result, DeclarationWithProximity dwp,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        Boolean isMember) {
        
        value unit = cu.unit;
        value dec = dwp.declaration;
        
        //proposal with type args
        if (is Generic dec) {
            value desc = getDescriptionFor2(dwp, unit, true);
            value text = getTextFor(dec, unit);
            
            result.add(newInvocationCompletion(offset, prefix,
                desc, text, dec, pr, scope, cmp,
                true, false, false,
                isLocation(ol, OccurrenceLocation.\iUPPER_BOUND)
                        || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                        || isLocation(ol, OccurrenceLocation.\iSATISFIES),
                isMember, null));
            
            if (dec.typeParameters.empty) {
                // don't add another proposal below!
                return;
            }
        }
        
        //proposal without type args
        value isAbstract = if (is Class dec) then dec.abstract else dec is Interface;
        if (!isAbstract && !isLocation(ol, OccurrenceLocation.\iEXTENDS) &&
            !isLocation(ol, OccurrenceLocation.\iSATISFIES) &&
            !isLocation(ol, OccurrenceLocation.\iUPPER_BOUND) ||
            !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS) &&
            !isLocation(ol, OccurrenceLocation.\iTYPE_ALIAS)) {
            
            value desc = getDescriptionFor2(dwp, unit, false);
            value text = escaping.escapeName(dec, unit);
            
            result.add(newInvocationCompletion(offset, prefix, desc, 
                text, dec, pr, scope, cmp, true, false, false,
                false, isMember, null));
        }
    }

    shared void addSecondLevelProposal(Integer offset, String prefix, 
        IdeComponent controller, MutableList<CompletionResult> result,
        Declaration dec, Scope scope, Boolean isMember, Reference pr,
        Type? requiredType, OccurrenceLocation? ol) {
        
        value unit = controller.lastCompilationUnit.unit;
        
        if (exists type = pr.type) {
            if (!(dec is Functional), !(dec is TypeDeclaration)) {
                //add qualified member proposals
                value members = type.declaration
                        .getMatchingMemberDeclarations(unit, scope, "", 0).values();
                for (ndwp in members) {
                    value m = ndwp.declaration;
                    if (m is FunctionOrValue || m is Class,
                        !ModelUtil.isConstructor(m)) {
                        
                        if (m.abstraction) {
                            for (o in m.overloads) {
                                addSecondLevelProposalInternal(offset, prefix,
                                    controller, result, dec, scope, requiredType,
                                    ol, unit, type, ndwp, o);
                            }
                        } else {
                            addSecondLevelProposalInternal(offset, prefix,
                                controller, result, dec, scope, requiredType,
                                ol, unit, type, ndwp, m);
                        }
                    }
                }
            }
            if (is Class dec) {
                //add constructor proposals
                value members = type.declaration.members;
                
                for (m in members) {
                    if (m is FunctionOrValue && ModelUtil.isConstructor(m) 
                        && m.shared && m.name exists) {
                        addSecondLevelProposalInternal(offset, prefix, controller,
                            result, dec, scope, requiredType, ol, unit, type, null, m);
                    }
                }
            }
        }
    }
    
    void addSecondLevelProposalInternal(
        Integer offset, String prefix,
        IdeComponent controller,
        MutableList<CompletionResult> result,
        Declaration dec, Scope scope,
        Type? requiredType, OccurrenceLocation? ol,
        Unit unit, Type type,
        DeclarationWithProximity? mwp,
        // sometimes we have no mwp so we also need the m
        Declaration m) {
        
        value ptr = type.getTypedReference(m, Collections.emptyList<Type>());
        
        if (exists mt = ptr.type) {
            value cond = if (exists requiredType)
            then withinBounds(requiredType, mt)
                    || dec is Class && dec==requiredType.declaration
            else true;
            
            if (cond) {
                value addParameterTypesInCompletions
                        = controller.options.parameterTypesInCompletion;
                value qualifier = dec.name + ".";
                value desc = qualifier + getPositionalInvocationDescriptionFor(
                    mwp, m, ol, ptr, unit, false, null,
                    addParameterTypesInCompletions);
                value text = qualifier + getPositionalInvocationTextFor(m, ol,
                    ptr, unit, false, null, addParameterTypesInCompletions);
                
                result.add(newInvocationCompletion(offset, prefix,
                        desc, text, m, ptr, scope, controller, true,
                        true, false,
                        isLocation(ol, OccurrenceLocation.\iUPPER_BOUND)
                                || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                                || isLocation(ol, OccurrenceLocation.\iSATISFIES),
                        true, dec));
            }
        }
    }
    
    // see InvocationCompletionProposal.addInvocationProposals()
    shared void addInvocationProposals(
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result,
        DeclarationWithProximity? dwp,
        // sometimes we have no dwp, just a dec, so we have to handle that too
        Declaration dec,
        Reference? pr, 
        Scope scope, OccurrenceLocation? ol,
        String? typeArgs, Boolean isMember) {
        
        if (is Functional fd = dec) {
            value unit = cmp.lastCompilationUnit.unit;
            value isAbstract = if (is TypeDeclaration dec, dec.abstract)
                               then true else false;
            value pls = fd.parameterLists;
            
            if (!pls.empty) {
                value parameterList = pls.get(0);
                value ps = parameterList.parameters;
                value exact = 
                        prefixWithoutTypeArgs(prefix, typeArgs) 
                            == dec.getName(unit);
                value inexactMatches = cmp.options.inexactMatches;
                value positional = exact
                        || "both"==inexactMatches
                        || "positional"==inexactMatches;
                value named = exact || "both"==inexactMatches;
                value addParameterTypesInCompletions = cmp.options.parameterTypesInCompletion;
                
                Boolean inheritance = isLocation(ol, OccurrenceLocation.\iUPPER_BOUND) 
                        || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                        || isLocation(ol, OccurrenceLocation.\iSATISFIES);

                if (positional, exists pr, 
                    parameterList.positionalParametersSupported,
                    !isAbstract || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                            || isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)) {

                    value parameters = getParameters(parameterList, false, false);
                    if (ps.size() != parameters.size()) {
                        value desc = getPositionalInvocationDescriptionFor(
                            dwp, dec, ol, pr, unit, false, typeArgs,
                            addParameterTypesInCompletions);
                        value text = getPositionalInvocationTextFor(dec, ol, pr,
                            unit, false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newInvocationCompletion(offset, prefix, desc,
                            text, dec, pr, scope, cmp, false, true, false,
                            inheritance, isMember, null));
                    }

                    value desc = getPositionalInvocationDescriptionFor(dwp, dec,
                        ol, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                    value text = getPositionalInvocationTextFor(dec, ol, pr,
                        unit, true, typeArgs, addParameterTypesInCompletions);

                    result.add(newInvocationCompletion(offset, prefix, desc,
                        text, dec, pr, scope, cmp, true, true, false, inheritance,
                        isMember, null));
                }
                if (named, parameterList.namedParametersSupported, exists pr,
                    !isAbstract && !isLocation(ol, OccurrenceLocation.\iEXTENDS) 
                            && !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)
                            && !dec.overloaded) {
                    
                    //if there is at least one parameter, 
                    //suggest a named argument invocation
                    value parameters = getParameters(parameterList, false, true);
                    if (ps.size() != parameters.size()) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr,
                            unit, false, typeArgs, addParameterTypesInCompletions);
                        value text =  getNamedInvocationTextFor(dec, pr, unit,
                            false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newInvocationCompletion(offset, prefix, desc,
                            text, dec, pr, scope, cmp, false, false, true,
                            inheritance, isMember, null));
                    }
                    if (!ps.empty) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr,
                            unit, true, typeArgs, addParameterTypesInCompletions);
                        value text = getNamedInvocationTextFor(dec, pr, unit,
                            true, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newInvocationCompletion(offset, prefix, desc,
                            text, dec, pr, scope, cmp, true, false, true,
                            inheritance, isMember, null));
                    }
                }
            }
        }
    }
    
    shared void addFakeShowParametersCompletion(Node node, IdeComponent cpc,
        MutableList<CompletionResult> result) {
        
        Tree.CompilationUnit? upToDateAndTypeChecked = cpc.typecheckedRootNode;
        if (!exists upToDateAndTypeChecked) {
            return;
        }
        object extends Visitor() {
            shared actual void visit(Tree.InvocationExpression that) {
                if (exists pal=that.positionalArgumentList else that.namedArgumentList) {
                    if (exists startIndex = pal.startIndex,
                        exists startIndex2 = node.startIndex, 
                        startIndex.intValue() == startIndex2.intValue()) {
                        
                        if (is Tree.MemberOrTypeExpression primary = that.primary) {
                            if (exists decl = primary.declaration,
                                
                                exists target = primary.target) {
                                result.add(newParameterInfo(startIndex.intValue(),
                                    decl, target, node.scope, cpc,
                                    pal is Tree.NamedArgumentList));
                            }
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(upToDateAndTypeChecked);
    }

    // see InvocationCompletionProposal.prefixWithoutTypeArgs
    String prefixWithoutTypeArgs(String prefix, String? typeArgs) {
        if (exists typeArgs) {
            return prefix.spanTo(prefix.size - typeArgs.size - 1);
        } else {
            return prefix;
        }
    }
}

shared abstract class InvocationCompletionProposal
        <IdeComponent,CompletionResult,IFile,Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode>
    (variable Integer _offset, String prefix, String desc, String text,
    Declaration declaration, Reference? producedReference, Scope scope,
    Tree.CompilationUnit cu, Boolean includeDefaulted, Boolean positionalInvocation,
    Boolean namedInvocation, Boolean inheritance, Boolean qualified,
    Declaration? qualifyingValue, 
    InvocationCompletion<IdeComponent,CompletionResult,Document> completionManager)
        extends AbstractCompletionProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region>
        (_offset, prefix, desc, text)
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit
        given IdeComponent satisfies LocalAnalysisResult<Document> {
    
    shared formal CompletionResult newNestedLiteralCompletionProposal(String val,
        Integer loc, Integer index);
    
    shared formal CompletionResult newNestedCompletionProposal(Declaration dec,
        Declaration? qualifier, Integer loc, Integer index, Boolean basic, String op);
    
    shared String getNestedCompletionText(String op, Unit unit, Declaration dec,
        Declaration? qualifier, Boolean basic, Boolean description) {
        value sb = StringBuilder().append(op);
        sb.append(getProposedName(qualifier, dec, unit));
        if (dec is Functional, !basic) {
            appendPositionalArgs(dec, dec.reference, unit, sb, false,
                description, false);
        }
        
        return sb.string;
    }

    shared Integer adjustedOffset => offset;
    
    shared TextChange createChange(TextChange change, Document document) {
        HashSet<Declaration> decs = HashSet<Declaration>();
        initMultiEditChange(change);
        
        if (exists qualifyingValue) {
            importProposals.importDeclaration(decs, qualifyingValue, cu);
        }
        if (!qualified) {
            importProposals.importDeclaration(decs, declaration, cu);
        }
        if (positionalInvocation || namedInvocation) {
            importProposals.importCallableParameterParamTypes(declaration, decs, cu);
        }
        value il = importProposals.applyImports(change, decs, cu, document);
        addEditToChange(change, createEdit(document));
        offset += il;
        return change;
    }
    
    shared void activeLinkedMode(Document document, IdeComponent cpc) {
        if (is Generic declaration) {
            variable ParameterList? paramList = null;
            if (is Functional fd = declaration,
                (positionalInvocation || namedInvocation)) {
                
                value pls = fd.parameterLists;
                if (!pls.empty, !pls.get(0).parameters.empty) {
                    paramList = pls.get(0);
                }
            }
            if (exists pl = paramList) {
                value params = getParameters(pl, includeDefaulted, namedInvocation);
                if (!params.empty) {
                    enterLinkedMode(document, params, null, cpc);
                    return; //NOTE: early exit!
                }
            }
            value typeParams = declaration.typeParameters;
            if (!typeParams.empty) {
                enterLinkedMode(document, null, typeParams, cpc);
            }
        }
    }
    
    shared actual Region getSelectionInternal(Document document) {
        value first = getFirstPosition();
        if (first <= 0) {
            //no arg list
            return super.getSelectionInternal(document);
        }
        value next = getNextPosition(document, first);
        if (next <= 0) {
            //an empty arg list
            return super.getSelectionInternal(document);
        }
        value middle = getCompletionPosition(first, next);
        variable value start = offset - prefix.size + first + middle;
        variable value len = next - middle;
        if (getDocSpan(document, start, len).trimmed=="{}") {
            start++;
            len = 0;
        }
        
        return newRegion(start, len);
    }
    
    Integer getCompletionPosition(Integer first, Integer next) 
            => (text.span(first, first + next - 2).lastOccurrence(' ') else -1) + 1;
    
    shared Integer getFirstPosition() {
        value index 
                = if (namedInvocation)
                then text.firstOccurrence('{')
                else if (positionalInvocation)
                then text.firstOccurrence('(')
                else text.firstOccurrence('<');
        return (index else -1) + 1;
    }
    
    shared Integer getNextPosition(Document document, Integer lastOffset) {
        value loc = offset - prefix.size;
        variable value comma = -1;
        value start = loc + lastOffset;
        variable value end = loc + text.size - 1;
        if (text.endsWith(";")) {
            end--;
        }
        comma = findCharCount(1, document, start, end, ",;", "", true, getDocChar)
                - start;
        
        if (comma < 0) {
            value index 
                    = if (namedInvocation)
                    then text.lastOccurrence('}')
                    else if (positionalInvocation)
                    then text.lastOccurrence(')')
                    else text.lastOccurrence('>');
            return (index else -1) - lastOffset;
        }
        return comma;
    }
    
    shared void enterLinkedMode(Document document, 
        JList<Parameter>? params, JList<TypeParameter>? typeParams, 
        IdeComponent cpc) {
        
        value proposeTypeArguments = !(params exists);
        value paramCount 
                = if (proposeTypeArguments)
                then (typeParams?.size() else 0)
                else (params?.size() else 0);
        if (paramCount == 0) {
            return;
        }
        try {
            value loc = offset - prefix.size;
            variable value first = getFirstPosition();
            if (first <= 0) {
                return; //no arg list
            }
            variable value next = getNextPosition(document, first);
            if (next <= 0) {
                return; //empty arg list
            }
            value linkedMode = newLinkedMode();
            variable value seq = 0;
            variable value param = 0;
            while (next>0 && param<paramCount) {
                // if proposeTypeArguments is false, params *should* exist
                value voidParam = !proposeTypeArguments
                        && (params?.get(param)?.declaredVoid else false);
                if (proposeTypeArguments || positionalInvocation
                        //don't create linked positions for
                        //void callable parameters in named
                        //argument lists
                        || !voidParam) {
                    
                    value props = ArrayList<CompletionResult>();
                    if (proposeTypeArguments) {
                        assert(exists typeParams);
                        addTypeArgumentProposals(props, typeParams.get(seq), 
                            loc, first, seq);
                    } else if (!voidParam) {
                        assert(exists params);
                        addValueArgumentProposals(props, params.get(param), 
                            loc, first, seq, param == params.size() - 1, cpc);
                    }
                    value middle = getCompletionPosition(first, next);
                    variable value start = loc + first + middle;
                    variable value len = next - middle;
                    if (voidParam) {
                        start++;
                        len = 0;
                    }
                    addEditableRegion(linkedMode, document, start, len, seq,
                        props.sequence());
                    first = first + next + 1;
                    next = getNextPosition(document, first);
                    seq++;
                }
                param++;
            }
            if (seq > 0) {
                installLinkedMode(document, linkedMode, this, seq, loc + text.size);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    void addValueArgumentProposals(MutableList<CompletionResult> props, 
        Parameter param, Integer loc, Integer first, Integer index, Boolean last, 
        IdeComponent cpc) {
        
        if (param.model.dynamicallyTyped) {
            return;
        }
        if (!exists producedReference) {
            return;
        }
        Type? type = producedReference.getTypedParameter(param).type;
        if (!exists type) {
            return;
        }

        value unit = cu.unit;
        value proposals = getSortedProposedValues(scope, unit, param.name);
        
        //very special case for print()
        value dname = declaration.qualifiedNameString;
        value print = "ceylon.language::print" == dname;
        if (print) {
            for (val in getAssignableLiterals(unit.stringType, unit)) {
                props.add(newNestedLiteralCompletionProposal(val, loc, index));
            }
        }
        
        //stuff defined in the same block, along with
        //stuff with fuzzily-matching name:
        for (dwp in proposals) {
            if (dwp.proximity <= 1) {
                addValueArgumentProposal(props, param, loc, index, last, 
                    type, unit, dwp, null, cpc);
            }
        }
        
        //this:
        if (exists ci = ModelUtil.getContainingClassOrInterface(scope),
            ci.type.isSubtypeOf(type)) {
            props.add(newNestedLiteralCompletionProposal("this", loc, index));
        }
        
        //literals:
        if (!print) {
            for (val in getAssignableLiterals(type, unit)) {
                props.add(newNestedLiteralCompletionProposal(val, loc, index));
            }
        }
        
        //stuff with lower proximity:
        for (dwp in proposals) {
            if (dwp.proximity > 1) {
                addValueArgumentProposal(props, param, loc, index, last, 
                    type, unit, dwp, null, cpc);
            }
        }
    }
    
    void addValueArgumentProposal(MutableList<CompletionResult> props, 
        Parameter p, Integer loc, Integer index, Boolean last, 
        Type type, Unit unit, 
        DeclarationWithProximity dwp, DeclarationWithProximity? qualifier, 
        IdeComponent cpc) {
        
        if (!qualifier exists && dwp.unimported) {
            return;
        }
        value dec = dwp.declaration;
        if (is NothingType dec) {
            return;
        }
        
        value pname = dec.unit.\ipackage.nameAsString;
        value isInLanguageModule 
                = !qualifier exists
                && pname == Module.\iLANGUAGE_MODULE_NAME;
        value qdec = qualifier?.declaration;
        
        if (is Value dec, 
            !(isInLanguageModule && isIgnoredLanguageModuleValue(dec)), 
            exists vt = dec.type, !vt.nothing) {
            if (withinBounds(type, vt)) {
                value isIterArg 
                        = namedInvocation && last
                        && unit.isIterableParameterType(type);
                value isVarArg = p.sequenced && positionalInvocation;
                value op = isIterArg || isVarArg then "*" else "";
                props.add(newNestedCompletionProposal(dec, qdec, 
                    loc, index, false, op));
            }
            if (!qualifier exists, cpc.options.chainLinkedModeArguments) {
                value members = 
                        dec.typeDeclaration
                           .getMatchingMemberDeclarations(unit, scope, "", 0)
                           .values();
                for (mwp in members) {
                    addValueArgumentProposal(props, p, loc, index, last, 
                        type, unit, mwp, dwp, cpc);
                }
            }
        }
        
        if (is Function dec, 
            !dec.annotation, 
            !(isInLanguageModule && isIgnoredLanguageModuleMethod(dec)), 
            exists mt = dec.type, !mt.nothing, 
            withinBounds(type, mt)) {
            value isIterArg 
                    = namedInvocation && last
                    && unit.isIterableParameterType(type);
            value isVarArg = p.sequenced && positionalInvocation;
            value op = isIterArg || isVarArg then "*" else "";
            props.add(newNestedCompletionProposal(dec, qdec, 
                loc, index, false, op));
        }
        
        if (is Class dec, 
            !dec.abstract && !dec.annotation, 
            !(isInLanguageModule && isIgnoredLanguageModuleClass(dec)), 
            exists ct = dec.type, 
            withinBounds(type, ct) || dec==type.declaration) {
            value isIterArg 
                    = namedInvocation && last
                    && unit.isIterableParameterType(type);
            value isVarArg = p.sequenced && positionalInvocation;
            if (dec.parameterList exists) {
                value op = isIterArg || isVarArg then "*" else "";
                props.add(newNestedCompletionProposal(dec, qdec, 
                    loc, index, false, op));
            }
            for (m in dec.members) {
                if (m is FunctionOrValue && ModelUtil.isConstructor(m) 
                    && m.shared && m.name exists) {
                    value op = isIterArg || isVarArg then "*" else "";
                    props.add(newNestedCompletionProposal(m, dec, 
                        loc, index, false, op));
                }
            }
        }
    }
    
    void addTypeArgumentProposals(MutableList<CompletionResult> props, 
        TypeParameter tp, Integer loc, Integer first, Integer index) {
        
        value ed = cu.unit.exceptionDeclaration;
        
        for (dwp in getSortedProposedValues(scope, cu.unit)) {
            value dec = dwp.declaration;
            value pname = dec.unit.\ipackage.nameAsString;
            value isInLanguageModule 
                    = pname == Module.\iLANGUAGE_MODULE_NAME;
            
            if (is TypeDeclaration dec, 
                !dwp.unimported, 
                !dec.type.nothing && dec.typeParameters.empty && 
                !dec.annotation && !dec.inherits(ed), 
                !(isInLanguageModule && isIgnoredLanguageModuleType(dec)), 
                inheritance && tp.isSelfType() 
                    then scope == dec
                    else isInBounds(tp.satisfiedTypes, dec.type)) {
                props.add(newNestedCompletionProposal(dec, null, 
                    loc, index, true, ""));
            }
        }
    }
    
}

