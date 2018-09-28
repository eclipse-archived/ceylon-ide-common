/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import org.eclipse.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    FindDeclarationNodeVisitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    ModelUtil,
    ClassOrInterface
}

shared object removeAnnotationQuickFix {
    
    shared void addRemoveAnnotationProposal(Node node, String annotation, QuickFixData data) {
        if (is Declaration dec = nodes.getReferencedDeclaration(node)) {
            addRemoveAnnotationInternal {
                node = node;
                annotation = annotation;
                desc = "Make Non" + annotation;
                dec = dec;
                data = data;
            };
        }
    }

    shared void addRemoveAnnotationDecProposal(String annotation, Node node, QuickFixData data) {
        if (is Tree.Declaration node) {
            addRemoveAnnotationInternal {
                node = node;
                annotation = annotation;
                desc = "Make Non" + annotation;
                dec = node.declarationModel;
                data = data;
            };
        }
    }

    shared void addMakeContainerNonfinalProposal(Node node, QuickFixData data) {
        Declaration dec;
        if (is Tree.Declaration node) {
            if (is Declaration container = node.declarationModel.container) {
                dec = container;
            } else {
                return;
            }
        } else {
            assert(is Declaration scope = node.scope);
            dec = scope;
        }
        addRemoveAnnotationInternal {
            node = node;
            annotation = "final";
            desc = "Make Nonfinal";
            dec = dec;
            data = data;
        };
    }
    
    void addRemoveAnnotationInternal(Node node, String annotation, String desc,
        Declaration? dec, QuickFixData data) {
        
        if (exists dec,
            exists d = dec.name,
            is AnyModifiableSourceFile unit = dec.unit,
            exists phasedUnit = unit.phasedUnit) {

            //TODO: "object" declarations?
            value fdv = FindDeclarationNodeVisitor(dec);
            phasedUnit.compilationUnit.visit(fdv);
            if (exists decNode = fdv.declarationNode) {
                assert (is Tree.Declaration decNode);
                addRemoveAnnotationProposalInternal(annotation, desc, dec,
                    phasedUnit, decNode, data);
            }
        }
    }
    
    void addRemoveAnnotationProposalInternal(String annotation, String desc,
        Declaration dec, PhasedUnit unit, Tree.Declaration decNode, QuickFixData data) {

        value change = platformServices.document.createTextChange(desc, unit);
        change.initMultiEdit();

        value offset = decNode.startIndex;
        for (a in decNode.annotationList.annotations) {
            assert (is Tree.BaseMemberExpression bme = a.primary);
            if (exists id = bme.identifier, id.text == annotation) {
                value args
                        = a.positionalArgumentList?.token exists
                        || a.namedArgumentList exists;
                change.addEdit(DeleteEdit {
                    start = a.startIndex.intValue();
                    length = a.endIndex.intValue()
                           - a.startIndex.intValue()
                           + (args then 0 else 1); //get rid of the trailing space
                });
            }
        }
        data.addQuickFix {
            description = description(annotation, dec);
            change = change;
            selection = DefaultRegion(offset.intValue());
            affectsOtherUnits = true;
        };
    }
    
    String description(String annotation, Declaration dec) {
        String nameWithQuotesAndSpace;
        if (exists name = dec.name) {
            nameWithQuotesAndSpace = "'``name``' ";
        } else if (dec.constructor) {
            nameWithQuotesAndSpace = "default constructor ";
        } else {
            nameWithQuotesAndSpace = "";
        }

        value descr = "Make ``nameWithQuotesAndSpace``non-``annotation``";
        if (is ClassOrInterface container = dec.container) {
            return descr + " in '``container.name``'";
        } else {
            return descr;
        }
    }

}
