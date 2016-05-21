import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    singularize
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    DeclarationWithProximity,
    Value
}

shared interface ControlStructureCompletionProposal<CompletionResult> {
    
    shared formal CompletionResult newControlStructureCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, LocalAnalysisResult cpc, Node? node = null);
    
    shared void addForProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (is Value d) {
            value td = d;
            if (exists t = td.type, 
                    d.unit.isIterableType(t) ||
                    d.unit.isJavaIterableType(t) ||
                    d.unit.isJavaArrayType(t)) {
                value name = d.name;
                value elemName = 
                        switch (name.size)
                        case (1) "element"
                        case (2) if (name.endsWith("s"))
                            then name.spanTo(0) 
                            else "element"
                        else let (singular = singularize(name))
                            if (singular==name)
                            then "element"
                            else singular;
                
                value unit = cpc.lastCompilationUnit.unit;
                value desc = "for (" + elemName + " in " + getDescriptionFor(d, unit) + ")";
                value text = "for (" + elemName + " in " + getTextFor(d, unit) + ") {}";
                
                result.add(newControlStructureCompletionProposal(offset, prefix, desc, text, d, cpc));
            }
        }
    }
    
    shared void addIfExistsProposal(Integer offset, String prefix, LocalAnalysisResult cpc,
        MutableList<CompletionResult> result, DeclarationWithProximity dwp,
        Declaration d, Node? node = null, String? forcedText = null) {
        
        if (!dwp.unimported) {
            if (is Value v = d) {
                if (exists type = v.type, d.unit.isOptionalType(type), !v.variable) {
                    value unit = cpc.lastCompilationUnit.unit;
                    value desc = "if (exists " 
                            + (forcedText else getDescriptionFor(d, unit)) + ")";
                    value text = "if (exists "
                            + (forcedText else getTextFor(d, unit)) + ") {}";
                    
                    result.add(newControlStructureCompletionProposal(offset, prefix,
                        desc, text, d, cpc, node));
                }
            }
        }
    }
    
    shared void addAssertExistsProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported) {
            if (is Value d) {
                value v = d;
                if (v.type exists, d.unit.isOptionalType(v.type), !v.variable) {
                    value unit = cpc.lastCompilationUnit.unit;
                    result.add(newControlStructureCompletionProposal(offset, prefix,
                            "assert (exists " + getDescriptionFor(d, unit) + ")",
                            "assert (exists " + getTextFor(d, unit) + ");", d, cpc));
                }
            }
        }
    }
    
    shared void addIfNonemptyProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported) {
            if (is Value v = d) {
                if (exists type = v.type, d.unit.isPossiblyEmptyType(type), !v.variable) {
                    value unit = cpc.lastCompilationUnit.unit;
                    value desc = "if (nonempty " + getDescriptionFor(d, unit) + ")";
                    value text = "if (nonempty " + getTextFor(d, unit) + ") {}";
                    result.add(newControlStructureCompletionProposal(offset, prefix, desc, text, d, cpc));
                }
            }
        }
    }
    
    shared void addAssertNonemptyProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported) {
            if (is Value d) {
                value v = d;
                if (v.type exists, d.unit.isPossiblyEmptyType(v.type), !v.variable) {
                    value unit = cpc.lastCompilationUnit.unit;
                    result.add(newControlStructureCompletionProposal(offset, prefix,
                            "assert (nonempty " + getDescriptionFor(d, unit) + ")",
                            "assert (nonempty " + getTextFor(d, unit) + ");",
                            d, cpc));
                }
            }
        }
    }
    
    shared void addTryProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported) {
            if (is Value d) {
                value v = d;
                if (exists type = v.type, v.type.declaration.inherits(d.unit.obtainableDeclaration), !v.variable) {
                    value unit = cpc.lastCompilationUnit.unit;
                    value desc = "try (" + getDescriptionFor(d, unit) + ")";
                    value text = "try (" + getTextFor(d, unit) + ") {}";
                    
                    result.add(newControlStructureCompletionProposal(offset, prefix, desc, text, d, cpc));
                }
            }
        }
    }
    
    shared void addSwitchProposal(Integer offset, String prefix, LocalAnalysisResult cpc, MutableList<CompletionResult> result,
        DeclarationWithProximity dwp, Declaration d, Node node) {
        
        if (!dwp.unimported) {
            if (is Value v = d) {
                if (exists type = v.type, exists caseTypes = v.type.caseTypes, !v.variable) {
                    value body = StringBuilder();
                    value indent = cpc.commonDocument.getIndent(node);
                    value unit = node.unit;
                    for (pt in caseTypes) {
                        body.append(indent).append("case (");
                        value ctd = pt.declaration;
                        if (ctd.anonymous) {
                            if (!ctd.toplevel) {
                                body.append(type.declaration.getName(unit)).append(".");
                            }
                            body.append(ctd.getName(unit));
                        } else {
                            body.append("is ").append(pt.asSourceCodeString(unit));
                        }
                        body.append(") {}").append(cpc.commonDocument.defaultLineDelimiter);
                    }
                    body.append(indent);
                    value u = cpc.lastCompilationUnit.unit;
                    value desc = "switch (" + getDescriptionFor(d, u) + ")";
                    value text = "switch (" + getTextFor(d, u) + ")"
                            + cpc.commonDocument.defaultLineDelimiter + body.string;
                    result.add(newControlStructureCompletionProposal(offset, prefix, desc, text, d, cpc));
                }
            }
        }
    }
}

shared abstract class ControlStructureProposal<CompletionResult>
        (Integer offset, String prefix, String desc, String text,
            Node? node, Declaration dec, LocalAnalysisResult cpc)
        
        extends AbstractCompletionProposal(offset, prefix, desc, text) {

    shared formal CompletionResult newNameCompletion(String? name);
    
    shared actual void applyInternal(CommonDocument document) {
        super.applyInternal(document);

        enterLinkedMode(cpc.commonDocument);
    }
    
    shared void enterLinkedMode(CommonDocument doc) {
        if (exists loc = text.firstInclusion(" val =")) {
            value linkedMode = platformServices.createLinkedMode(doc);
            
            value startOffset = node?.startIndex?.intValue() else offset;
            value exitOffset = text.endsWith("{}")
                                then startOffset + text.size - 1
                                else startOffset + text.size;
            
            linkedMode.addEditableRegion( 
                startOffset + loc + 1, 3, 0, 
                nodes.nameProposals {
                        node = node;
                        unplural = false;
                        rootNode = cpc.parsedRootNode;
                    }.collect(newNameCompletion));
            
            linkedMode.install(this, 1, exitOffset);
        }
    }
    
    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
        if (exists loc = text.firstInclusion(" val =")) {
            return DefaultRegion(offset + loc + 1 - prefix.size, 3);
        } else {
            value loc = text.firstOccurrence('}') 
                        else ((text.firstOccurrence(';') else - 1) + 1);
            return DefaultRegion(offset + loc - prefix.size, 0);
        }
    }
}