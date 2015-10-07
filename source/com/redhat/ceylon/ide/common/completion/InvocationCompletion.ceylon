import ceylon.collection {
    MutableList,
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
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
    Function
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import java.lang {
    JInteger=Integer
}
import ceylon.interop.java {
    CeylonIterable
}
import java.util {
    Collections,
    HashSet,
    JList=List
}

shared interface InvocationCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact> 
        given IdeArtifact satisfies Object {
    
    shared formal String inexactMatches;
    
    shared formal Boolean addParameterTypesInCompletions;
    
    shared formal CompletionResult newPositionalInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, IdeComponent cmp,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted, Declaration? qualifyingDec);

    shared formal CompletionResult newNamedInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, IdeComponent cmp,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted);

    shared formal CompletionResult newReferenceCompletion(Integer offset, String prefix, String desc, String text,
        Declaration dec, Unit u, Reference? pr, Scope scope, IdeComponent cmp, Boolean isMember, Boolean includeTypeArgs);
    
    shared formal CompletionResult newParameterInfo(Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, IdeComponent cpc, Boolean namedInvocation);
    
    shared formal CompletionResult newNestedLiteralCompletionProposal(String val, Integer loc, Integer index);
    
    shared formal CompletionResult newNestedCompletionProposal(Declaration dec, Declaration? qualifier, Integer loc,
        Integer index, Boolean basic, String op);
    
    // TODO     static void addProgramElementReferenceProposal(int offset, String prefix, 
    //        CeylonParseController cpc, List<ICompletionProposal> result, 
    //        Declaration dec, Scope scope, boolean isMember) {

    // see InvocationCompletionProposal.addInvocationProposals()
    shared void addInvocationProposals(
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        String? typeArgs, Boolean isMember) {
        
        if (is Functional fd = dec) {
            value unit = cmp.rootNode.unit;
            value isAbstract = if (is TypeDeclaration dec, dec.abstract) then true else false;
            value pls = fd.parameterLists;
            
            if (!pls.empty) {
                value parameterList = pls.get(0);
                value ps = parameterList.parameters;
                value exact = prefixWithoutTypeArgs(prefix, typeArgs)
                        .equals(dec.getName(unit));
                value positional = exact
                        || "both".equals(inexactMatches)
                        || "positional".equals(inexactMatches);
                value named = exact || "both".equals(inexactMatches);
                
                if (positional, exists pr, 
                    parameterList.positionalParametersSupported,
                    !isAbstract || isLocation(ol, OccurrenceLocation.\iEXTENDS)
                            || isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)) {

                    value parameters = getParameters(parameterList, false, false);
                    if (ps.size() != parameters.size()) {
                        value desc = getPositionalInvocationDescriptionFor(dec, ol, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        value text = getPositionalInvocationTextFor(dec, ol, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newPositionalInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, false, null));
                    }

                    value desc = getPositionalInvocationDescriptionFor(dec, ol, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                    value text = getPositionalInvocationTextFor(dec, ol, pr, unit, true, typeArgs, addParameterTypesInCompletions);

                    result.add(newPositionalInvocationCompletion(offset, prefix, desc, text, dec,
                        pr, scope, cmp, isMember, typeArgs, true, null));
                }
                if (named, parameterList.namedParametersSupported, exists pr,
                    !isAbstract && !isLocation(ol, OccurrenceLocation.\iEXTENDS) 
                            && !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS)
                            && !dec.overloaded) {
                    
                    value parameters = getParameters(parameterList, false, true);
                    if (ps.size() != parameters.size()) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        value text =  getNamedInvocationTextFor(dec, pr, unit, false, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newNamedInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, false));
                    }
                    if (!ps.empty) {
                        value desc = getNamedInvocationDescriptionFor(dec, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                        value text = getNamedInvocationTextFor(dec, pr, unit, true, typeArgs, addParameterTypesInCompletions);
                        
                        result.add(newNamedInvocationCompletion(offset, prefix, desc, text,
                            dec, pr, scope, cmp, isMember, typeArgs, true));
                    }
                }
            }
        }
    }
    
    // see InvocationCompletionProposal.addReferenceProposal()
    shared void addReferenceProposal(Tree.CompilationUnit cu,
        Integer offset, String prefix, IdeComponent cmp,
        MutableList<CompletionResult> result, Declaration dec,
        Reference? pr, Scope scope, OccurrenceLocation? ol,
        Boolean isMember) {
        
        value unit = cu.unit;
        
        //proposal with type args
        if (is Generic dec) {
            value desc = getDescriptionFor(dec, unit);
            value text = getTextFor(dec, unit);
            
            result.add(newReferenceCompletion(offset, prefix, desc, text, dec, unit, pr, scope, cmp, isMember, true));
            
            if (dec.typeParameters.empty) {
                // don't add another proposal below!
                return;
            }
        }
        
        //proposal without type args
        value isAbstract = if (is Class dec) then dec.abstract else dec is Interface;
        if (!isAbstract, !isLocation(ol, OccurrenceLocation.\iEXTENDS),
            !isLocation(ol, OccurrenceLocation.\iSATISFIES),
            !isLocation(ol, OccurrenceLocation.\iCLASS_ALIAS),
            !isLocation(ol, OccurrenceLocation.\iTYPE_ALIAS)) {
            
            value desc = dec.getName(unit);
            value text = escaping.escapeName(dec, unit);

            result.add(newReferenceCompletion(offset, prefix, desc, text, dec, unit, pr, scope, cmp, isMember, false));
        }
    }
    
    shared void addFakeShowParametersCompletion(Node node, IdeComponent cpc, MutableList<CompletionResult> result) {
        object extends Visitor() {
            
            shared actual void visit(Tree.InvocationExpression that) {
                Tree.ArgumentList? al = that.positionalArgumentList else that.namedArgumentList;

                if (exists pal=al) {
                    JInteger? startIndex = pal.startIndex;
                    JInteger? startIndex2 = node.startIndex;
                    if (exists startIndex, exists startIndex2, startIndex.intValue() == startIndex2.intValue()) {
                        if (is Tree.MemberOrTypeExpression primary = that.primary) {
                            if (exists decl = primary.declaration, exists target = primary.target) {
                                result.add(newParameterInfo(startIndex.intValue(), decl, target, node.scope, cpc, pal is Tree.NamedArgumentList));
                            }
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(cpc.rootNode);
    }

    shared void addSecondLevelProposal(Integer offset, String prefix, IdeComponent controller, MutableList<CompletionResult> result,
            Declaration dec, Scope scope, Boolean isMember, Reference pr, Type? requiredType, OccurrenceLocation? ol) {
        
        if (!(dec is Functional), !(dec is TypeDeclaration)) {
            value unit = controller.rootNode.unit;
            value type = pr.type;
            if (ModelUtil.isTypeUnknown(type)) {
                return;
            }
            value members = type.declaration.getMatchingMemberDeclarations(unit, scope, "", 0).values();
            for (ndwp in CeylonIterable(members)) {
                value m = ndwp.declaration;
                if ((m is FunctionOrValue || m is Class), !ModelUtil.isConstructor(m)) {
                    addSecondLevelProposalInternal(offset, prefix, controller, result, dec, scope, requiredType, ol, unit, type, m);
                }
            }
        }
        if (is Class dec) {
            value unit = controller.rootNode.unit;
            value type = pr.type;
            if (ModelUtil.isTypeUnknown(type)) {
                return;
            }
            value members = type.declaration.getMatchingMemberDeclarations(unit, scope, "", 0).values();
            for (ndwp in CeylonIterable(members)) {
                value m = ndwp.declaration;
                if (ModelUtil.isConstructor(m)) {
                    addSecondLevelProposalInternal(offset, prefix, controller, result, dec, scope, requiredType, ol, unit, type, m);
                }
            }
        }
    }

    void addSecondLevelProposalInternal(Integer offset, String prefix, IdeComponent controller, MutableList<CompletionResult> result,
            Declaration dec, Scope scope, Type? requiredType, OccurrenceLocation? ol, Unit unit, Type type, Declaration m) {
        value ptr = type.getTypedReference(m, Collections.emptyList<Type>());
        
        if (exists mt = ptr.type, (requiredType is Null || mt.isSubtypeOf(requiredType))) {
            value qualifier = dec.name + ".";
            value desc = qualifier + getPositionalInvocationDescriptionFor(m, ol, ptr, unit, false, null, addParameterTypesInCompletions);
            value text = qualifier + getPositionalInvocationTextFor(m, ol, ptr, unit, false, null, addParameterTypesInCompletions);
            result.add(newPositionalInvocationCompletion(offset, prefix, desc, text, m, ptr, scope, controller, true, null, true, dec));
        }
    }

    // see InvocationCompletionProposal.prefixWithoutTypeArgs
    String prefixWithoutTypeArgs(String prefix, String? typeArgs) {
        if (exists typeArgs) {
            return prefix.span(0, prefix.size - typeArgs.size);
        } else {
            return prefix;
        }
    }
}

shared abstract class InvocationCompletionProposal<IdeComponent,IdeArtifact,CompletionResult,IFile,Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode>
    (variable Integer _offset, String prefix, String desc, String text, Declaration declaration, Reference? producedReference,
    Scope scope, Tree.CompilationUnit cu, Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation,
    Boolean qualified, Declaration? qualifyingValue, InvocationCompletion<IdeComponent,IdeArtifact,CompletionResult,Document> completionManager)
        extends AbstractCompletionProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region>
        (_offset, prefix, desc, text)
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
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
    
    shared void activeLinkedMode(Document document) {
        if (is Generic declaration) {
            value generic = declaration;
            variable ParameterList? paramList = null;
            if (is Functional fd = declaration, (positionalInvocation || namedInvocation)) {
                value pls = fd.parameterLists;
                if (!pls.empty, !pls.get(0).parameters.empty) {
                    paramList = pls.get(0);
                }
            }
            if (exists pl = paramList) {
                value params = getParameters(pl, includeDefaulted, namedInvocation);
                if (!params.empty) {
                    enterLinkedMode(document, params, null);
                    return; //NOTE: early exit!
                }
            }
            value typeParams = generic.typeParameters;
            if (!typeParams.empty) {
                enterLinkedMode(document, null, typeParams);
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
        if (getDocSpan(document, start, len).trimmed.equals("{}")) {
            start++;
            len = 0;
        }
        
        return newRegion(start, len);
    }
    
    Integer getCompletionPosition(Integer first, Integer next) {
        return (text.span(first, first + next - 1).lastOccurrence(' ') else -1) + 1;
    }
    
    Integer getFirstPosition() {
        Integer? index;
        if (namedInvocation) {
            index = text.firstOccurrence('{');
        } else if (positionalInvocation) {
            index = text.firstOccurrence('(');
        } else {
            index = text.firstOccurrence('<');
        }
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
        comma = findCharCount(1, document, start, end, ",;", "", true, getDocChar) - start;
        
        if (comma < 0) {
            Integer? index;
            if (namedInvocation) {
                index = text.lastOccurrence('}');
            } else if (positionalInvocation) {
                index = text.lastOccurrence(')');
            } else {
                index = text.lastOccurrence('>');
            }
            return (index else -1) - lastOffset;
        }
        return comma;
    }
    
    shared void enterLinkedMode(Document document, JList<Parameter>? params, JList<TypeParameter>? typeParams) {
        value proposeTypeArguments = !(params exists);
        value paramCount = if (proposeTypeArguments) then (typeParams?.size() else 0) else (params?.size() else 0);
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
                value voidParam = !proposeTypeArguments && (params?.get(param)?.declaredVoid else false);
                if (proposeTypeArguments || positionalInvocation
                        //don't create linked positions for
                        //void callable parameters in named
                        //argument lists
                        || !voidParam) {
                    
                    value props = ArrayList<CompletionResult>();
                    if (proposeTypeArguments) {
                        assert(exists typeParams);
                        addTypeArgumentProposals(typeParams.get(seq), loc, first, props, seq);
                    } else if (!voidParam) {
                        assert(exists params);
                        addValueArgumentProposals(params.get(param), loc, first, props, seq, param == params.size() - 1);
                    }
                    value middle = getCompletionPosition(first, next);
                    variable value start = loc + first + middle;
                    variable value len = next - middle;
                    if (voidParam) {
                        start++;
                        len = 0;
                    }
                    addEditableRegion(linkedMode, document, start, len, seq, props.sequence());
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
    
    void addValueArgumentProposals(Parameter p, Integer loc, Integer first, MutableList<CompletionResult> props, Integer index, Boolean last) {
        if (p.model.dynamicallyTyped) {
            return;
        }
        assert(exists producedReference);
        Type? type = producedReference.getTypedParameter(p).type;
        if (!exists type) {
            return;
        }

        value unit = cu.unit;
        value proposals = CeylonIterable(getSortedProposedValues(scope, unit));
        for (dwp in proposals) {
            if (dwp.proximity <= 1) {
                addValueArgumentProposal(p, loc, props, index, last, type, unit, dwp, null);
            }
        }
        addLiteralProposals(loc, props, index, type, unit);
        for (dwp in proposals) {
            if (dwp.proximity > 1) {
                addValueArgumentProposal(p, loc, props, index, last, type, unit, dwp, null);
            }
        }
    }
    
    void addValueArgumentProposal(Parameter p, Integer loc, MutableList<CompletionResult> props, 
        Integer index, Boolean last, Type type, Unit unit, DeclarationWithProximity dwp, DeclarationWithProximity? qualifier) {
        
        if (!exists qualifier, dwp.unimported) {
            return;
        }
        value td = type.declaration;
        value d = dwp.declaration;
        value pname = d.unit.\ipackage.nameAsString;
        value isInLanguageModule = !(qualifier exists) && pname.equals(Module.\iLANGUAGE_MODULE_NAME);
        value qdec = if (!exists qualifier) then null else qualifier.declaration;
        if (is Value d) {
            value \ivalue = d;
            if (isInLanguageModule) {
                if (isIgnoredLanguageModuleValue(\ivalue)) {
                    return;
                }
            }
            Type? vt = \ivalue.type;
            if (exists vt, !vt.nothing) {
                if (vt.isSubtypeOf(type) || withinBounds(td, vt)) {
                    value isIterArg = namedInvocation && last && unit.isIterableParameterType(type);
                    value isVarArg = p.sequenced && positionalInvocation;
                    props.add(completionManager.newNestedCompletionProposal(d, qdec, loc, index, false, if (isIterArg || isVarArg) then "*" else ""));
                }
                if (!exists qualifier/*TODO , preferences.getBoolean(\iCHAIN_LINKED_MODE_ARGUMENTS)*/) {
                    value members = \ivalue.typeDeclaration.getMatchingMemberDeclarations(unit, scope, "", 0).values();
                    for (mwp in CeylonIterable(members)) {
                        addValueArgumentProposal(p, loc, props, index, last, type, unit, mwp, dwp);
                    }
                }
            }
        }
        if (is Function method = d, !d.annotation) {
            if (isInLanguageModule) {
                if (isIgnoredLanguageModuleMethod(method)) {
                    return;
                }
            }
            Type? mt = method.type;
            if (exists mt, !mt.nothing) {
                if (mt.isSubtypeOf(type) || withinBounds(td, mt)) {
                    value isIterArg = namedInvocation && last && unit.isIterableParameterType(type);
                    value isVarArg = p.sequenced && positionalInvocation;
                    props.add(completionManager.newNestedCompletionProposal(d, qdec, loc, index, false, if (isIterArg || isVarArg) then "*" else ""));
                }
            }
        }
        if (is Class d) {
            value clazz = d;
            if (!clazz.abstract, !d.annotation) {
                if (isInLanguageModule) {
                    if (isIgnoredLanguageModuleClass(clazz)) {
                        return;
                    }
                }
                Type? ct = clazz.type;
                if (exists ct, !ct.nothing, (withinBounds(td, ct) || ct.declaration.equals(type.declaration) || ct.isSubtypeOf(type))) {
                    value isIterArg = namedInvocation && last && unit.isIterableParameterType(type);
                    value isVarArg = p.sequenced && positionalInvocation;
                    props.add(completionManager.newNestedCompletionProposal(d, qdec, loc, index, false, if (isIterArg || isVarArg) then "*" else ""));
                }
            }
        }
    }
    
    Boolean withinBounds(TypeDeclaration td, Type vt) {
        if (is TypeParameter td) {
            value tp = td;
            return isInBounds(tp.satisfiedTypes, vt);
        } else {
            return false;
        }
    }
    
    void addLiteralProposals(Integer loc, MutableList<CompletionResult> props, Integer index, Type type, Unit unit) {
        value dtd = unit.getDefiniteType(type).declaration;
        if (is Class dtd) {
            if (dtd.equals(unit.integerDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("0", loc, index));
                props.add(completionManager.newNestedLiteralCompletionProposal("1", loc, index));
            }
            if (dtd.equals(unit.floatDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("0.0", loc, index));
                props.add(completionManager.newNestedLiteralCompletionProposal("1.0", loc, index));
            }
            if (dtd.equals(unit.stringDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("\"\"", loc, index));
            }
            if (dtd.equals(unit.characterDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("' '", loc, index));
                props.add(completionManager.newNestedLiteralCompletionProposal("'\\n'", loc, index));
                props.add(completionManager.newNestedLiteralCompletionProposal("'\\t'", loc, index));
            }
        } else if (is Interface dtd) {
            if (dtd.equals(unit.iterableDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("{}", loc, index));
            }
            if (dtd.equals(unit.sequentialDeclaration) || dtd.equals(unit.emptyDeclaration)) {
                props.add(completionManager.newNestedLiteralCompletionProposal("[]", loc, index));
            }
        }
    }
    
    void addTypeArgumentProposals(TypeParameter tp, Integer loc, Integer first, MutableList<CompletionResult> props, Integer index) {
        for (dwp in CeylonIterable(getSortedProposedValues(scope, cu.unit))) {
            value d = dwp.declaration;
            if (d is TypeDeclaration, !dwp.unimported) {
                assert (is TypeDeclaration td = d);
                value t = td.type;
                if (!t.nothing, td.typeParameters.empty, !td.annotation, !td.inherits(td.unit.exceptionDeclaration)) {
                    if (td.unit.\ipackage.nameAsString.equals(Module.\iLANGUAGE_MODULE_NAME)) {
                        if (isIgnoredLanguageModuleType(td)) {
                            continue;
                        }
                    }
                    if (isInBounds(tp.satisfiedTypes, t)) {
                        props.add(completionManager.newNestedCompletionProposal(d, null, loc, index, true, ""));
                    }
                }
            }
        }
    }
}
