import ceylon.collection {
    MutableList,
    ArrayList
}
import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Scope,
    Interface,
    Reference,
    Type,
    Generic,
    FunctionOrValue,
    Module,
    Value,
    Function,
    Class,
    Constructor,
    Unit,
    Functional,
    ModelUtil,
    NothingType,
    DeclarationWithProximity
}

import java.util {
    JArrayList=ArrayList,
    HashSet
}

// see RefinementCompletionProposal
shared interface RefinementCompletion<IdeComponent,CompletionResult, Document>
        given IdeComponent satisfies LocalAnalysisResult<Document> {
    
    shared formal CompletionResult newRefinementCompletionProposal(Integer offset, 
        String prefix, Reference? pr, String desc, String text, IdeComponent cmp,
        Declaration dec, Scope scope, Boolean fullType, Boolean explicitReturnType);

    // see RefinementCompletionProposal.addRefinementProposal(...)
    shared void addRefinementProposal(Integer offset, Declaration dec, 
        ClassOrInterface ci, Node node, Scope scope, String prefix, IdeComponent cpc,
        MutableList<CompletionResult> result, Boolean preamble, Indents<Document> indents,
        Boolean addParameterTypesInCompletions) {
        
        value isInterface = scope is Interface;
        value pr = getRefinedProducedReference(scope, dec);
        value unit = node.unit;
        value doc = cpc.document;
        
        value desc = getRefinementDescriptionFor(dec, pr, unit);
        value text = getRefinementTextFor(dec, pr, unit, isInterface, ci, 
                        indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc), 
                        true, preamble, indents, addParameterTypesInCompletions);
        
        result.add(newRefinementCompletionProposal(offset, prefix, pr, desc,
            text, cpc, dec, scope, false, true));
    }

    shared void addNamedArgumentProposal(Integer offset, String prefix, IdeComponent cpc,
        MutableList<CompletionResult> result, Declaration dec, Scope scope) {
        
        //TODO: type argument substitution using the
        //     Reference of the primary node
        value unit = cpc.lastCompilationUnit.unit;
        value desc = getDescriptionFor(dec, unit);
        value text = getTextFor(dec, unit) + " = nothing;";
        
        result.add(newRefinementCompletionProposal(offset, prefix,
            dec.reference,  //TODO: this needs to do type arg substitution
            desc, text, cpc, dec, scope, true, false));
    }
    
    shared void addInlineFunctionProposal(Integer offset, Declaration dec, Scope scope, Node node, String prefix,
        IdeComponent cmp, Document doc, MutableList<CompletionResult> result, Indents<Document> indents) {
        
        //TODO: type argument substitution using the
        //      Reference of the primary node
        if (dec.parameter, is FunctionOrValue dec) {
            value p = dec.initializerParameter;
            value unit = node.unit;
            value desc = getInlineFunctionDescriptionFor(p, null, unit);
            value text = getInlineFunctionTextFor(p, null, unit, 
                indents.getDefaultLineDelimiter(doc) + indents.getIndent(node, doc));
            
            result.add(newRefinementCompletionProposal(offset, prefix, 
                dec.reference,  //TODO: this needs to do type arg substitution 
                desc, text, cmp, dec, scope, false, false));
        }
    }
    
    // see getRefinedProducedReference(Scope scope, Declaration d)
    shared Reference? getRefinedProducedReference(Scope|Type scope, Declaration d) {
        if (is Type scope) {
            value superType = scope;
            if (superType.intersection) {
                for (pt in superType.satisfiedTypes) {
                    if (exists result = getRefinedProducedReference(pt, d)) {
                        return result;
                    }
                }
                return null;
            } else {
                if (exists declaringType = superType.declaration.getDeclaringType(d)) {
                    value outerType = superType.getSupertype(declaringType.declaration);
                    return refinedProducedReference(outerType, d);
                } else {
                    return null;
                }
            }
        } else {
            return refinedProducedReference(scope.getDeclaringType(d), d);
        }
    }

    // see refinedProducedReference(Type outerType, Declaration d)
    Reference refinedProducedReference(Type outerType, 
        Declaration d) {
        value params = JArrayList<Type>();
        if (is Generic d) {
            for (tp in d.typeParameters) {
                params.add(tp.type);
            }
        }
        return d.appliedReference(outerType, params);
    }
}

shared abstract class RefinementCompletionProposal<IdeComponent,CompletionResult,IFile,Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode>
        (Integer _offset, String prefix, Reference pr, String desc, 
        String text, IdeComponent cpc, Declaration declaration, Scope scope,
        Boolean fullType, Boolean explicitReturnType)
        extends AbstractCompletionProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region>
        (_offset, prefix, desc, text)
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit
        given IdeComponent satisfies LocalAnalysisResult<Document> {

    shared formal CompletionResult newNestedLiteralCompletionProposal(String val, Integer loc);
    shared formal CompletionResult newNestedCompletionProposal(Declaration dec, Integer loc);

    shared String getNestedCompletionText(Boolean description, Unit unit, Declaration dec) {
        value sb = StringBuilder();
        sb.append(getProposedName(null, dec, unit));
        if (is Functional dec) {
            appendPositionalArgs(dec, dec.reference, unit, sb, false, description, false);
        }
        return sb.string;
    }

    Type? type => if (fullType) then pr.fullType else pr.type;

    shared actual Region getSelectionInternal(Document document) {
        value loc = text.firstInclusion("nothing;");
        Integer length;
        variable Integer start;
        if (!exists loc) {
            start = offset + text.size - prefix.size;
            if (text.endsWith("{}")) {
                start--;
            }
            
            length = 0;
        } else {
            start = offset + loc - prefix.size;
            length = 7;
        }

        return newRegion(start, length);
    }

    shared TextChange createChange(TextChange change, Document document) {
        initMultiEditChange(change);
        value decs = HashSet<Declaration>();
        value cu = cpc.lastCompilationUnit;
        if (explicitReturnType) {
            importProposals.importSignatureTypes(declaration, cu, decs);
        } else {
            importProposals.importParameterTypes(declaration, cu, decs);
        }
        
        value il = importProposals.applyImports(change, decs, cu, document);
        addEditToChange(change, createEdit(document));
        offset += il;
        return change;
    }

    shared void enterLinkedMode(Document document) {
        try {
            value loc = offset - prefix.size;
            
            if (exists pos = text.firstInclusion("nothing")) {
                value linkedModeModel = newLinkedMode();
                value props = ArrayList<CompletionResult>();
                addProposals(loc + pos, prefix, props);
                addEditableRegion(linkedModeModel, document, loc + pos, 7, 0, props.sequence());
                installLinkedMode(document, linkedModeModel, this, 1, loc + text.size);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void addProposals(Integer loc, String prefix, MutableList<CompletionResult> props) {
        value t = type;
        if (!exists t) {
            return;
        }
        
        value unit = cpc.lastCompilationUnit.unit;
        
        // nothing:
        props.add(newNestedCompletionProposal(
            unit.getLanguageModuleDeclaration("nothing"), loc));
        
        // this:
        if (exists ci = ModelUtil.getContainingClassOrInterface(scope),
            ci.type.isSubtypeOf(type)) {
            props.add(newNestedLiteralCompletionProposal("this", loc));
        }
        
        // literals:
        for (val in getAssignableLiterals(t, unit)) {
            props.add(newNestedLiteralCompletionProposal(val, loc));
        }
        
        // declarations:
        for (dwp in getSortedProposedValues(scope, unit)) {
            addValueProposals(props, loc, prefix, t, dwp);
        }
    }
    
    void addValueProposals(MutableList<CompletionResult> props, 
        Integer loc, String prefix, Type t, DeclarationWithProximity dwp) {
        if (dwp.unimported) {
            //don't propose unimported stuff b/c adding
            //imports drops us out of linked mode and
            //because it results in a pause
            return;
        }
        value d = dwp.declaration;
        if (is NothingType d) {
            return;
        }
        
        value split = javaString(prefix).split("\\s+");
        if (split.size > 0, d.name==split.get(split.size - 1)) {
            return;
        }
        value pname = d.unit.\ipackage.nameAsString;
        value inLanguageModule 
                = pname == Module.\iLANGUAGE_MODULE_NAME;
        if (is Value val = d, d!=declaration,
            !(inLanguageModule && isIgnoredLanguageModuleValue(val)), 
            exists vt = val.type, !vt.nothing, 
            withinBounds(t, vt) || vt.isSubtypeOf(type)) {
            
            props.add(newNestedCompletionProposal(d, loc));
        }
        if (is Function method = d, d!=declaration, !d.annotation,
            !(inLanguageModule && isIgnoredLanguageModuleMethod(method)), 
            exists mt = method.type, !mt.nothing,
            withinBounds(t, mt) || mt.isSubtypeOf(type)) {
            
            props.add(newNestedCompletionProposal(d, loc));
        }
        if (is Class clazz = d, !clazz.abstract, !d.annotation,
            !(inLanguageModule && isIgnoredLanguageModuleClass(clazz)), 
            exists ct = clazz.type, !ct.nothing,
            withinBounds(t, ct)
                    || ct.declaration==t.declaration
                    || ct.isSubtypeOf(type)) {
            
            if (clazz.parameterList exists) {
                props.add(newNestedCompletionProposal(d, loc));
            }
            
            for (m in clazz.members) {
                if (is Constructor m, m.shared, m.name exists) {
                    props.add(newNestedCompletionProposal(m, loc));
                }
            }
        }
    }
    
}
