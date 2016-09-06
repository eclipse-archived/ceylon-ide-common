import com.redhat.ceylon.ide.common.completion {
    getAssignableLiterals,
    getSortedProposedValues,
    isIgnoredLanguageModuleValue,
    isIgnoredLanguageModuleMethod,
    isInBounds,
    isIgnoredLanguageModuleClass,
    ProposalsHolder,
    getCurrentSpecifierRegion,
    getProposedName,
    appendPositionalArgs
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    TextChange
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    NothingType,
    Module,
    Value,
    Function,
    TypeDeclaration,
    Type,
    TypeParameter,
    Constructor,
    Class,
    Unit,
    Scope,
    Declaration,
    Functional
}

shared object initializerQuickFix {
    
    shared void apply(TextChange change, CommonDocument sourceDocument, Unit unit) {
        
        if (sourceDocument != change.document) {
            platformServices.gotoLocation(unit, 0, 0);
        }

        change.apply();
    }

    shared void applyWithLinkedMode(TextChange change, 
        CommonDocument sourceDocument, DefaultRegion selection, Type? type,
        Unit unit, Scope scope, variable Integer exitPos) {
        
        value targetDocument = change.document;
        
        if (sourceDocument != targetDocument) {
            platformServices.gotoLocation(unit, 0, 0);
            exitPos = -1;
        }

        value lenBefore = targetDocument.size;
        change.apply();
        value lenAfter = targetDocument.size;

        value lmDocument = 
                platformServices.gotoLocation(unit, selection.start, selection.length)
                else targetDocument;
        
        //TODO: preference to disable linked mode?
        if (lenAfter > lenBefore,
            selection.length > 0) {
            
            value lm = platformServices.createLinkedMode(lmDocument);
            value proposals = getProposals {
                document = lmDocument;
                loc = selection.start;
                type = type;
                unit = unit;
                scope = scope;
            };
            if (!proposals.empty) {
                lm.addEditableRegion {
                    start = selection.start;
                    length = selection.length;
                    exitSeqNumber = 0;
                    proposals = proposals;
                };
                value adjustedPos = if (exitPos >= 0, exitPos > selection.start)
                                    then exitPos + lenAfter - lenBefore
                                    else exitPos;
                value exitSeq = (exitPos >= 0) then 1 else -1;
                lm.install(this, exitSeq, adjustedPos);
            }
        }
    }
    
    void addNestedLiteralCompletionProposal(CommonDocument document,
        ProposalsHolder proposals, String val, Integer offset) {
        
        value region = getCurrentSpecifierRegion(document, offset);
        
        platformServices.completion.addNestedProposal {
            proposals = proposals;
            description = val;
            region = region;
            icon = Icons.ceylonLiteral;
        };
    }

    void addNestedCompletionProposal(CommonDocument document, 
        ProposalsHolder proposals, Declaration dec, Integer offset) {
        
        value region = getCurrentSpecifierRegion(document, offset);
        
        function getText(Boolean description) {
            value sb = StringBuilder();
            sb.append(getProposedName(null, dec, dec.unit));
            if (is Functional dec) {
                appendPositionalArgs(dec, null, dec.unit,
                    sb, false, description, false);
            }
            
            return sb.string;
        }
        
        platformServices.completion.addNestedProposal {
            proposals = proposals;
            icon = dec;
            description = getText(true);
            region = region;
            text = getText(false);
        };
    }
    
    ProposalsHolder getProposals(CommonDocument document, 
        Integer loc, Type? type, Unit unit, Scope scope) {
        
        value proposals = platformServices.completion.createProposalsHolder();
        
//            //this is totally lame
//            //TODO: see InvocationCompletionProcessor
//            proposals.add(new NestedLiteralCompletionProposal(
//                    document.get(point.x, point.y), point.x));

        addValueArgumentProposals {
            document = document;
            loc = loc;
            type = type;
            unit = unit;
            scope = scope;
            props = proposals;
        };
        
        return proposals;
    }

    void addValueArgumentProposals(CommonDocument document, Integer loc, Type? type,
        Unit unit, Scope scope, ProposalsHolder props) {
        
        if (!exists type) {
            return;
        }
        
        for (val in getAssignableLiterals(type, unit)) {
            addNestedLiteralCompletionProposal(document, props, val, loc);
        }
        
        value td = type.declaration;
        for (dwp in getSortedProposedValues(scope, unit)) {
            if (dwp.unimported) {
                continue;
            }
            
            value d = dwp.declaration;
            if (is NothingType d) {
                return;
            }
            
            value pname = d.unit.\ipackage.nameAsString;
            value inLangModule = pname.equals(Module.languageModuleName);
            if (is Value d) {
                if (inLangModule) {
                    if (isIgnoredLanguageModuleValue(d)) {
                        continue;
                    }
                }
                
                if (exists vt = d.type,
                    !vt.nothing,
                    (isTypeParamInBounds(td, vt) || vt.isSubtypeOf(type))) {
                    
                    addNestedCompletionProposal(document, props, d, loc);
                }
            }
            
            if (is Function d) {
                if (!d.annotation) {
                    if (inLangModule) {
                        if (isIgnoredLanguageModuleMethod(d)) {
                            continue;
                        }
                    }
                    
                    if (exists mt = d.type,
                        !mt.nothing,
                        (isTypeParamInBounds(td, mt) || mt.isSubtypeOf(type))) {
                        
                        addNestedCompletionProposal(document, props, d, loc);
                    }
                }
            }
            
            if (is Class d) {
                if (!d.abstract, !d.annotation) {
                    if (inLangModule) {
                        if (isIgnoredLanguageModuleClass(d)) {
                            continue;
                        }
                    }
                    
                    if (exists ct = d.type,
                        !ct.nothing,
                        (isTypeParamInBounds(td, ct)
                            || ct.declaration.equals(type.declaration)
                            || ct.isSubtypeOf(type))) {
                        
                        if (d.parameterList exists) {
                            addNestedCompletionProposal(document, props, d, loc);
                        }
                        
                        for (m in d.members) {
                            if (m is Constructor, m.shared, m.name exists) {
                                addNestedCompletionProposal(document, props, m, loc);
                            }
                        }
                    }
                }
            }
        }
    }
    
    Boolean isTypeParamInBounds(TypeDeclaration td, Type t)
            => td is TypeParameter
            && isInBounds(td.satisfiedTypes, t);
}
