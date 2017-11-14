/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
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
import org.eclipse.ceylon.ide.common.completion {
    appendParameter
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    DeleteEdit,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    types
}
import org.eclipse.ceylon.model.typechecker.model {
    TypedDeclaration,
    TypeDeclaration,
    Type,
    Declaration,
    Functional
}

import java.util {
    Collections
}

shared object changeRefiningTypeQuickFix {
    
    shared void addProposal(QuickFixData data) {
        if (is Tree.TypedDeclaration td
                 = nodes.findDeclaration {
                    cu = data.rootNode;
                    node = data.node;
                }) {
            value dec = td.declarationModel;
            value rd = types.getRefinedDeclaration(dec);

            //TODO: this can return the wrong member when
            //      there are multiple ... better to look
            //      at what RefinementVisitor does
            if (is TypedDeclaration rd,
                is TypeDeclaration decContainer = dec.container,
                is TypeDeclaration rdContainer = rd.container) {
                value supertype 
                        = decContainer.type.getSupertype(rdContainer);
                value ref 
                        = rd.appliedReference(supertype, 
                            Collections.emptyList<Type>());
                value t = ref.type;
                value type = t.asSourceCodeString(td.unit);
                
                value change 
                        = platformServices.document.createTextChange {
                    name = "Change Type";
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
                
                value importProposals 
                        = CommonImportProposals {
                    document = change.document;
                    rootNode = data.rootNode;
                };
                importProposals.importType(t);
                importProposals.apply(change);
                
                change.addEdit(ReplaceEdit {
                    start = data.node.startIndex.intValue();
                    length = data.node.distance.intValue();
                    text = type;
                });
                data.addQuickFix {
                    description = "Change type to '``type``'";
                    change = change;
                    selection = DefaultRegion {
                        start = data.node.startIndex.intValue();
                        length = type.size;
                    };
                };
            }
        }
    }
    
    shared void addChangeRefiningParametersProposal(QuickFixData data) {
        assert (is Tree.Statement decNode 
            = nodes.findStatement(data.rootNode, data.node));
        
        Tree.ParameterList list;
        Declaration dec;
        
        switch (decNode)
        case (is Tree.AnyMethod) {
            list = decNode.parameterLists.get(0);
            dec = decNode.declarationModel;
        }
        case (is Tree.AnyClass) {
            list = decNode.parameterList;
            dec = decNode.declarationModel;
        }
        case (is Tree.SpecifierStatement) {
            value lhs = decNode.baseMemberExpression;
            if (is Tree.ParameterizedExpression lhs) {
                value pe = lhs;
                list = pe.parameterLists.get(0);
                dec = decNode.declaration;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        
        variable Declaration rd = dec.refinedDeclaration;
        if (dec == rd) {
            rd = dec.container.getDirectMember(dec.name, null, false);
        }
        
        if (is Functional rf = rd, is Functional f = dec) {
            value rdPls = rf.parameterLists;
            value decPls = f.parameterLists;
            if (rdPls.empty || decPls.empty) {
                return;
            }
            
            value rdpl = rdPls.get(0).parameters;
            value dpl = decPls.get(0).parameters;
            value decContainer = dec.container;
            value rdContainer = rd.container;

            Type? supertype;
            if (is TypeDeclaration decContainer,
                is TypeDeclaration rdContainer) {
                supertype 
                        = decContainer.type
                            .getSupertype(rdContainer);
            } else {
                supertype = null;
            }
            
            value pr 
                    = rd.appliedReference(supertype, 
                        Collections.emptyList<Type>());
            value params = list.parameters;
            value change 
                    = platformServices.document.createTextChange {
                name = "Fix Refining Parameter List";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            value unit = decNode.unit;
            value importProposals 
                    = CommonImportProposals {
                document = change.document;
                rootNode = data.rootNode;
            };
            
            variable value i = 0;            
            while (i < params.size()) {
                value p = params.get(i);
                if (rdpl.size() <= i) {
                    value start 
                            = if (i == 0)
                            then list.startIndex.intValue() + 1
                            else params.get(i-1).endIndex.intValue();
                    value stop 
                            = params.get(params.size() - 1).endIndex.intValue();
                    change.addEdit(DeleteEdit {
                        start = start;
                        length = stop - start;
                    });
                    break;
                }
                else {
                    value rdp = rdpl.get(i);
                    value pt = pr.getTypedParameter(rdp).fullType;
                    value dt = dpl.get(i).model.typedReference.fullType;
                    if (!dt.isExactly(pt)) {
                        change.addEdit(ReplaceEdit {
                            start = p.startIndex.intValue();
                            length = p.distance.intValue();
                            //TODO: better handling for callable parameters
                            text = pt.asSourceCodeString(unit) + " " + rdp.name;
                        });
                        importProposals.importType(pt);
                    }
                }
                
                i++;
            }
            
            if (rdpl.size() > params.size()) {
                value buf = StringBuilder();
                variable value j = params.size();
                while (j < rdpl.size()) {
                    value rdp = rdpl.get(j);
                    if (j > 0) {
                        buf.append(", ");
                    }
                    
                    appendParameter(buf, pr, rdp, unit, false);
                    value pt = pr.getTypedParameter(rdp).fullType;
                    importProposals.importType(pt);
                    j++;
                }
                
                change.addEdit(InsertEdit {
                    start 
                        = if (params.empty) 
                        then list.startIndex.intValue() + 1
                        else params.get(params.size() - 1).endIndex.intValue();
                    text = buf.string;
                });
            }
            
            importProposals.apply(change);
            
            if (change.hasEdits) {
                data.addQuickFix {
                    description = "Fix refining parameter list";
                    change = change;
                    selection = DefaultRegion {
                        start = list.startIndex.intValue() + 1;
                    };
                };
            }
        }
    }
}
