import org.eclipse.ceylon.compiler.typechecker.tree {
    Node
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    platformServices
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import org.eclipse.ceylon.ide.common.util {
    singularize
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    DeclarationWithProximity,
    Value
}

shared interface ControlStructureCompletionProposal {
    
    shared void addForProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (is Value d,
            exists t = d.type,
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

            value unit = ctx.lastCompilationUnit.unit;

            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "for (``elemName`` in ``getDescriptionFor(d, unit)``)";
                    text = "for (``elemName`` in ``getTextFor(d, unit)``) {}";
                    dec = d;
                    cpc = ctx;
                };
        }
    }
    
    shared void addIfExistsProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp,
        Declaration d, Node? node = null, String? forcedText = null) {
        
        if (!dwp.unimported,
            is Value d,
            exists type = d.type,
            d.unit.isOptionalType(type),
            !d.variable) {
            value unit = ctx.lastCompilationUnit.unit;

            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "if (exists ``forcedText else getDescriptionFor(d, unit)``)";
                    text = "if (exists ``forcedText else getTextFor(d, unit)``) {}";
                    dec = d;
                    cpc = ctx;
                    node = node;
                };
        }
    }
    
    shared void addAssertExistsProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported,
            is Value d,
            d.type exists,
            d.unit.isOptionalType(d.type),
            !d.variable) {
            value unit = ctx.lastCompilationUnit.unit;
            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "assert (exists ``getDescriptionFor(d, unit)``)";
                    text = "assert (exists ``getTextFor(d, unit)``);";
                    dec = d;
                    cpc = ctx;
                };
        }
    }
    
    shared void addIfNonemptyProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported,
            is Value d,
            exists type = d.type,
            d.unit.isPossiblyEmptyType(type),
            !d.variable) {
            value unit = ctx.lastCompilationUnit.unit;
            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "if (nonempty ``getDescriptionFor(d, unit)``)";
                    text = "if (nonempty ``getTextFor(d, unit)``) {}";
                    dec = d;
                    cpc = ctx;
                };
        }
    }
    
    shared void addAssertNonemptyProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported,
            is Value d,
            d.type exists,
            d.unit.isPossiblyEmptyType(d.type),
            !d.variable) {
            value unit = ctx.lastCompilationUnit.unit;
            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "assert (nonempty ``getDescriptionFor(d, unit)``)";
                    text = "assert (nonempty ``getTextFor(d, unit)``);";
                    dec = d;
                    cpc = ctx;
                };
        }
    }
    
    shared void addTryProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d) {
        
        if (!dwp.unimported,
            is Value d,
            exists type = d.type,
            d.type.declaration.inherits(d.unit.obtainableDeclaration),
            !d.variable) {
            value unit = ctx.lastCompilationUnit.unit;

            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "try (``getDescriptionFor(d, unit)``)";
                    text = "try (``getTextFor(d, unit)``) {}";
                    dec = d;
                    cpc = ctx;
                };
        }
    }
    
    shared void addSwitchProposal(Integer offset, String prefix, CompletionContext ctx,
        DeclarationWithProximity dwp, Declaration d, Node node) {
        
        if (!dwp.unimported,
            is Value d,
            exists type = d.type,
            exists caseTypes = d.type.caseTypes,
            !d.variable) {
            value body = StringBuilder();
            value indent = ctx.commonDocument.getIndent(node);
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
                body.append(") {}").append(ctx.commonDocument.defaultLineDelimiter);
            }
            body.append(indent);
            value u = ctx.lastCompilationUnit.unit;

            platformServices.completion
                .newControlStructureCompletionProposal {
                    offset = offset;
                    prefix = prefix;
                    desc = "switch (``getDescriptionFor(d, u)``)";
                    text = "switch (``getTextFor(d, u)``)"
                    + ctx.commonDocument.defaultLineDelimiter + body.string;
                    dec = d;
                    cpc = ctx;
                };
        }
    }
}

shared abstract class ControlStructureProposal
        (Integer offset, String prefix, String desc, String text,
            Node? node, Declaration dec, LocalAnalysisResult cpc)
        
        extends AbstractCompletionProposal(offset, prefix, desc, text) {

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
        value loc = (text.firstOccurrence('{') else text.firstOccurrence(';') else -1) + 1;
        return DefaultRegion(offset + loc - prefix.size);
    }
}