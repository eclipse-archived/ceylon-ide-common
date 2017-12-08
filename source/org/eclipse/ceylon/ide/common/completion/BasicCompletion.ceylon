/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.platform {
    platformServices
}
import org.eclipse.ceylon.ide.common.util {
    escaping
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Scope
}

shared interface BasicCompletion {
    
    shared void addImportProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            description = dec.name;
            text = escaping.escapeName(dec);
            icon = dec;
        };
    }
    
    shared void addDocLinkProposal(Integer offset, String prefix,
        CompletionContext ctx, Declaration dec, Scope scope) {
        
        //for doc links, propose both aliases and unaliased qualified form
        //we don't need to do this in code b/c there is no fully-qualified form
        String name = dec.name;
        value unit = ctx.lastCompilationUnit.unit;
        String aliasedName = dec.getName(unit);

        if (name!=aliasedName) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                description = aliasedName;
                icon = dec;
            };
        }
        
        platformServices.completion.addProposal {
            ctx = ctx;
            offset = offset;
            prefix = prefix;
            description = name;
            text = getTextForDocLink(unit, dec);
            icon = dec;
        };
    }
}
