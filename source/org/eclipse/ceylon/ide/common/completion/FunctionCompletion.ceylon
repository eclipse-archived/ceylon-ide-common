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

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.correct {
    importProposals
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    TextChange
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Functional
}

shared interface FunctionCompletion {

    shared void addFunctionProposal(Integer offset, CompletionContext ctx,
        Tree.Primary primary, Declaration dec) {

        variable Tree.Term arg = primary;
        while (is Tree.Expression a = arg) {
            arg = a.term;
        }

        value start = arg.startIndex.intValue();
        value stop = arg.endIndex.intValue();
        value origin = primary.startIndex.intValue();
        value doc = ctx.commonDocument;
        value argText = doc.getText(start, stop - start);
        value prefix = doc.getText(origin, offset - origin);
        value unit = ctx.lastCompilationUnit.unit;
        
        platformServices.completion.newFunctionCompletionProposal {
            offset = offset;
            prefix = prefix;
            desc = getDescriptionFor(dec, unit) + "(...)";
            text = dec.getName(arg.unit) + "(``argText``)"
                 + (if (is Functional dec, dec.declaredVoid) then ";" else "");
            dec = dec;
            unit = unit;
            cmp = ctx;
        };
    }

}

shared abstract class FunctionCompletionProposal  
        (Integer _offset, String prefix, String desc, String text, Declaration declaration, Tree.CompilationUnit rootNode)
        extends AbstractCompletionProposal(_offset, prefix, desc, text) {
    
    shared TextChange createChange(CommonDocument document) {
        value change = platformServices.document.createTextChange("Complete Invocation", document);
        value decs = HashSet<Declaration>();
        importProposals.importDeclaration(decs, declaration, rootNode);
        value il = importProposals.applyImports(change, decs, rootNode, document);
        change.addEdit(createEdit(document));
        offset += il;
        return change;
    }
}
