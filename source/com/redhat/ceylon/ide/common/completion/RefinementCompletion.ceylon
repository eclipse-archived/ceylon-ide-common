import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.correct {
    importProposals
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    TextChange,
    platformServices
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
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
shared interface RefinementCompletion {

    // see RefinementCompletionProposal.addRefinementProposal(...)
    shared void addRefinementProposal(Integer offset, Declaration dec, 
        ClassOrInterface ci, Node node, Scope scope, String prefix, CompletionContext ctx,
        Boolean preamble, Boolean addParameterTypesInCompletions) {
        
        value isInterface = scope is Interface;
        value pr = getRefinedProducedReference(scope, dec);
        value unit = node.unit;
        
        value desc = getRefinementDescriptionFor(dec, pr, unit);
        value text = getRefinementTextFor(dec, pr, unit, isInterface, ci, 
                        ctx.commonDocument.defaultLineDelimiter + ctx.commonDocument.getIndent(node), 
                        true, preamble, addParameterTypesInCompletions);
        
        platformServices.completion.newRefinementCompletionProposal {
            offset = offset;
            prefix = prefix;
            pr = pr;
            desc = desc;
            text = text;
            cmp = ctx;
            dec = dec;
            scope = scope;
            fullType = false;
            explicitReturnType = true;
        };
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

    shared void addNamedArgumentProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        //TODO: type argument substitution using the
        //     Reference of the primary node
        value unit = ctx.lastCompilationUnit.unit;
        value desc = getDescriptionFor(dec, unit);
        value text = getTextFor(dec, unit) + " = nothing;";
        
        platformServices.completion.newRefinementCompletionProposal(offset, prefix,
            dec.reference,  //TODO: this needs to do type arg substitution
            desc, text, ctx, dec, scope, true, false);
    }
    
    shared void addInlineFunctionProposal(Integer offset, Declaration dec, 
        Scope scope, Node node, String prefix, CompletionContext ctx, 
        CommonDocument doc) {
        
        //TODO: type argument substitution using the
        //      Reference of the primary node
        if (dec.parameter, is FunctionOrValue dec) {
            value p = dec.initializerParameter;
            value unit = node.unit;
            value desc = getInlineFunctionDescriptionFor(p, null, unit);
            value text = getInlineFunctionTextFor(p, null, unit, 
                ctx.commonDocument.defaultLineDelimiter + ctx.commonDocument.getIndent(node));
            
            platformServices.completion.newRefinementCompletionProposal {
                offset = offset;
                prefix = prefix;
                pr = dec.reference; //TODO: this needs to do type arg substitution 
                desc = desc;
                text = text;
                cmp = ctx;
                dec = dec;
                scope = scope;
                fullType = false;
                explicitReturnType = false;
            };
        }
    }

}

shared abstract class RefinementCompletionProposal
        (Integer _offset, String prefix, Reference pr, String desc, 
        String text, LocalAnalysisResult cpc, Declaration declaration, Scope scope,
        Boolean fullType, Boolean explicitReturnType)
        extends AbstractCompletionProposal
        (_offset, prefix, desc, text) {

    // TODO move to CompletionServices
    shared formal void newNestedLiteralCompletionProposal(ProposalsHolder proposals, String val, Integer loc);
    shared formal void newNestedCompletionProposal(ProposalsHolder proposals, Declaration dec, Integer loc);

    shared String getNestedCompletionText(Boolean description, Unit unit, Declaration dec) {
        value sb = StringBuilder();
        sb.append(getProposedName(null, dec, unit));
        if (is Functional dec) {
            appendPositionalArgs(dec, dec.reference, unit, sb, false, description, false);
        }
        return sb.string;
    }

    Type? type => if (fullType) then pr.fullType else pr.type;

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
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

        return DefaultRegion(start, length);
    }

    shared TextChange createChange(CommonDocument document) {
        value change = platformServices.createTextChange("Add Refinement", document);
        value decs = HashSet<Declaration>();
        value cu = cpc.lastCompilationUnit;
        if (explicitReturnType) {
            importProposals.importSignatureTypes(declaration, cu, decs);
        } else {
            importProposals.importParameterTypes(declaration, cu, decs);
        }
        
        value il = importProposals.applyImports(change, decs, cu, document);
        change.addEdit(createEdit(document));
        offset += il;
        return change;
    }

    shared void enterLinkedMode(CommonDocument document) {
        try {
            value loc = offset - prefix.size;
            
            if (exists pos = text.firstInclusion("nothing")) {
                value linkedModeModel = platformServices.createLinkedMode(document);
                value props = platformServices.completion.createProposalsHolder();
                addProposals(loc + pos, prefix, props);
                linkedModeModel.addEditableRegion(loc + pos, 7, 0, props);
                linkedModeModel.install(this, 1, loc + text.size);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void addProposals(Integer loc, String prefix, ProposalsHolder props) {
        value t = type;
        if (!exists t) {
            return;
        }
        
        value unit = cpc.lastCompilationUnit.unit;
        
        // nothing:
        newNestedCompletionProposal(props,
            unit.getLanguageModuleDeclaration("nothing"), loc);
        
        // this:
        if (exists ci = ModelUtil.getContainingClassOrInterface(scope),
            ci.type.isSubtypeOf(type)) {
            newNestedLiteralCompletionProposal(props, "this", loc);
        }
        
        // literals:
        for (val in getAssignableLiterals(t, unit)) {
            newNestedLiteralCompletionProposal(props, val, loc);
        }
        
        // declarations:
        for (dwp in getSortedProposedValues(scope, unit)) {
            addValueProposals(props, loc, prefix, t, dwp);
        }
    }
    
    void addValueProposals(ProposalsHolder props, 
        Integer loc, String prefix, Type type, 
        DeclarationWithProximity dwp) {
        if (dwp.unimported) {
            //don't propose unimported stuff b/c adding
            //imports drops us out of linked mode and
            //because it results in a pause
            return;
        }
        value dec = dwp.declaration;
        if (is NothingType dec) {
            return;
        }
        
        value split = javaString(prefix).split("\\s+");
        if (split.size > 0, 
            dec.name==split.get(split.size-1).string) {
            return;
        }
        value pname = dec.unit.\ipackage.nameAsString;
        value inLanguageModule 
                = pname == Module.\iLANGUAGE_MODULE_NAME;
        
        if (is Value dec, 
            dec!=declaration,
            !(inLanguageModule && isIgnoredLanguageModuleValue(dec)), 
            exists vt = dec.type, !vt.nothing, 
            withinBounds(type, vt, scope)) {
            
            newNestedCompletionProposal(props, dec, loc);
        }
        
        if (is Function dec, 
            dec!=declaration, !dec.annotation,
            !(inLanguageModule && isIgnoredLanguageModuleMethod(dec)), 
            exists mt = dec.type, !mt.nothing,
            withinBounds(type, mt, scope)) {
            
            newNestedCompletionProposal(props, dec, loc);
        }
        
        if (is Class dec, 
            !dec.abstract, !dec.annotation,
            !(inLanguageModule && isIgnoredLanguageModuleClass(dec)), 
            exists ct = dec.type, !ct.nothing,
            withinBounds(type, ct, scope) || ct.declaration==type.declaration) {
            
            if (dec.parameterList exists) {
                newNestedCompletionProposal(props, dec, loc);
            }
            
            for (m in dec.members) {
                if (is Constructor m, m.shared, m.name exists) {
                    newNestedCompletionProposal(props, m, loc);
                }
            }
        }
    }
    
}
