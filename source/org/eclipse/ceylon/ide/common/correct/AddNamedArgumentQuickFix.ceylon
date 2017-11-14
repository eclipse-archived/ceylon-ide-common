/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import java.lang {
    Types {
        nativeString
    }
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object addNamedArgumentQuickFix {
    
    shared void addNamedArgumentsProposal(QuickFixData data) {
        if (is Tree.NamedArgumentList node = data.node) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Add Named Arguments";
                input = data.phasedUnit;
            };
            value doc = change.document;
            change.initMultiEdit();
            
            value nal = node;
            value args = nal.namedArgumentList;
            value start = nal.startIndex.intValue();
            value stop = nal.endIndex.intValue() - 1;
            variable value loc = start + 1;
            variable value sep = " ";
            value nas = nal.namedArguments;
            
            if (!nas.empty) {
                value last = nas.get(nas.size() - 1);
                loc = last.endIndex.intValue();
                value firstLine = doc.getLineOfOffset(start);
                value lastLine = doc.getLineOfOffset(stop);
                
                if (firstLine != lastLine) {
                    sep = doc.defaultLineDelimiter 
                            + doc.getIndent(last);
                }
            }
            variable String? result = null;
            variable value multipleResults = false;
            for (param in args.parameterList.parameters) {
                if (!param.defaulted, 
                    !nativeString(param.name) in args.argumentNames) {
                    multipleResults = result exists;
                    result = param.name;
                    change.addEdit(InsertEdit {
                        start = loc;
                        text = sep + param.name + " = nothing;";
                    });
                }
            }
            
            if (loc == stop) {
                change.addEdit(InsertEdit {
                    start = stop;
                    text = " ";
                });
            }
            
            data.addQuickFix {
                description 
                    = if (exists name = result, !multipleResults)
                    then "Fill in missing named argument '``name``'"
                    else "Fill in missing named arguments";
                change = change;
                selection = DefaultRegion(loc);
            };
        }
    }
}
