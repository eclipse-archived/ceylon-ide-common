/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    HashSet
}
import java.lang {
    Types {
        nativeString
    }
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Node
}
import org.eclipse.ceylon.ide.common.correct {
    importProposals
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    TextChange,
    platformServices
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Scope,
    Interface,
    Reference,
    Type,
    Module,
    Value,
    Function,
    Class,
    Constructor,
    Unit,
    Functional,
    ModelUtil,
    NothingType,
    DeclarationWithProximity,
    TypedReference
}

import java.util {
    JArrayList=ArrayList
}

// see RefinementCompletionProposal
shared interface RefinementCompletion {

    // see RefinementCompletionProposal.addRefinementProposal(...)
    shared void addRefinementProposal(Integer offset, Declaration dec, 
        ClassOrInterface ci, Node node, Scope scope, String prefix, CompletionContext ctx,
        Boolean preamble, Boolean addParameterTypesInCompletions) {

        value pr = getRefinedProducedReference(scope, dec);
        value unit = node.unit;
        
        value desc = getRefinementDescriptionFor(dec, pr, unit);
        value text
                = getRefinementTextFor {
                    d = dec;
                    pr = pr;
                    unit = unit;
                    isInterface = scope is Interface;
                    ci = ci;
                    indent
                        = ctx.commonDocument.defaultLineDelimiter
                        + ctx.commonDocument.getIndent(node);
                    containsNewline = true;
                    preamble = preamble;
                    addParameterTypesInCompletions = addParameterTypesInCompletions;
                };
        
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
            if (scope.intersection) {
                for (pt in scope.satisfiedTypes) {
                    if (exists result = getRefinedProducedReference(pt, d)) {
                        return result;
                    }
                }
                return null;
            } else {
                if (exists declaringType = scope.declaration.getDeclaringType(d)) {
                    value outerType = scope.getSupertype(declaringType.declaration);
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
        for (tp in d.typeParameters) {
            params.add(tp.type);
        }
        return d.appliedReference(outerType, params);
    }

    shared void addNamedArgumentProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope, TypedReference? pr) {
        
        value unit = ctx.lastCompilationUnit.unit;
        
        platformServices.completion.newRefinementCompletionProposal {
            offset = offset;
            prefix = prefix;
            pr = pr;
            desc = getDescriptionFor(dec, unit);
            text = getTextFor(dec, unit) + " = nothing;";
            cmp = ctx;
            dec = dec;
            scope = scope;
            fullType = true;
            explicitReturnType = false;
        };
    }
    
    shared void addInlineFunctionProposal(Integer offset, Declaration dec, 
        Scope scope, Node node, String prefix, CompletionContext ctx, TypedReference? pr,
        CommonDocument doc) {
        
        if (dec.parameter, is Function dec) {
            value p = dec.initializerParameter;
            value unit = node.unit;
            
            platformServices.completion.newRefinementCompletionProposal {
                offset = offset;
                prefix = prefix;
                pr = pr;
                desc = getInlineFunctionDescriptionFor(p, pr, unit);
                text = getInlineFunctionTextFor {
                    p = p;
                    pr = pr;
                    unit = unit;
                    indent = ctx.commonDocument.defaultLineDelimiter
                           + ctx.commonDocument.getIndent(node);
                };
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
        String text, CompletionContext ctx, Declaration declaration, Scope scope,
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
            appendPositionalArgs {
                d = dec;
                pr = dec.reference;
                unit = unit;
                result = sb;
                includeDefaulted = false;
                descriptionOnly = description;
                addParameterTypesInCompletions = false;
            };
        }
        return sb.string;
    }

    Type? type => fullType then pr.fullType else pr.type;

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {

        Integer length;
        variable Integer start;
        if (exists loc = text.firstInclusion("nothing;")) {
            start = offset + loc - prefix.size;
            length = 7;
        }
        else {
            start = offset + text.size - prefix.size;
            if (text.endsWith("{}")) {
                start--;
            }

            length = 0;
        }

        return DefaultRegion(start, length);
    }

    shared TextChange createChange(CommonDocument document) {
        value change = platformServices.document.createTextChange("Add Refinement", document);
        value decs = HashSet<Declaration>();
        value cu = ctx.lastCompilationUnit;
        if (explicitReturnType) {
            importProposals.importSignatureTypes(declaration, cu, decs, scope);
        } else {
            importProposals.importParameterTypes(declaration, cu, decs, scope);
        }
        
        value il = importProposals.applyImports(change, decs, cu, document, scope);
        change.addEdit(createEdit(document));
        offset += il;
        return change;
    }

    shared void enterLinkedMode(CommonDocument document) {
        try {
            value loc = offset - prefix.size;
            
            if (exists pos = text.firstInclusion("nothing"),
                ctx.options.linkedModeArguments) {
                value linkedModeModel = platformServices.createLinkedMode(document);
                value props = platformServices.completion.createProposalsHolder();
                addProposals(loc + pos, prefix, props);
                linkedModeModel.addEditableRegion(loc + pos, 7, 0, props);
                linkedModeModel.install(this, 1, loc + text.size);
            }
        } catch (e) {
            e.printStackTrace();
        }
    }

    void addProposals(Integer loc, String prefix, ProposalsHolder props) {
        if (exists t = type) {
            value unit = ctx.lastCompilationUnit.unit;

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
        
        value split = nativeString(prefix).split("\\s+");
        if (split.size > 0, 
            dec.name==split.get(split.size-1).string) {
            return;
        }
        value pname = dec.unit.\ipackage.nameAsString;
        value inLanguageModule 
                = pname == Module.languageModuleName;
        
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
