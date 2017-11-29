/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    InsertEdit,
    CommonDocument,
    LinkedMode
}
import org.eclipse.ceylon.ide.common.util {
    escaping
}

import org.antlr.runtime {
    CommonToken
}

shared object convertToClassQuickFix {
    
    shared void addConvertToClassProposal(QuickFixData data, Tree.Declaration? declaration) {
        if (is Tree.ObjectDefinition declaration) {
            value desc = "Convert '``declaration.identifier.text``' to class";
            data.addConvertToClassProposal(desc, declaration);
        }
    }

    shared void applyChanges(CommonDocument doc, Tree.ObjectDefinition node, LinkedMode? mode = null) {
        value name = node.identifier.text;
        value initialName = escaping.toInitialUppercase(name);
        value change = platformServices.document.createTextChange("Convert to Class", doc);
        change.initMultiEdit();
        
        assert(is CommonToken tok = node.mainToken);
        value dstart = tok.startIndex;
        
        change.addEdit(ReplaceEdit(dstart, 6, "class"));
        value start = node.identifier.startIndex.intValue();
        value length = node.identifier.distance.intValue();
        
        change.addEdit(ReplaceEdit(start, length, initialName + "()"));
        value offset = node.endIndex.intValue();
        //TODO: handle actual object declarations
        value mods = if (node.declarationModel.shared) then "shared " else "";
        value ws = doc.defaultLineDelimiter + doc.getIndent(node);
        value impl = " = " + initialName + "();";
        value dec = ws + mods + initialName + " " + name;
        
        change.addEdit(InsertEdit(offset, dec + impl));
        
        change.apply();
        
        value lm = mode else platformServices.createLinkedMode(doc);
        
        lm.addEditableGroup( 
            [start - 1, length, 0],
            [offset + ws.size + mods.size + 1, length, 1],
            [offset + dec.size + 4, length, 2]
        );
        
        lm.install(this, -1, start - 1);
    }
}
