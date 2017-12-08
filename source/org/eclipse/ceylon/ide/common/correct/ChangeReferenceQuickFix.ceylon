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
import org.eclipse.ceylon.compiler.typechecker.util {
    NormalizedLevenshtein
}
import org.eclipse.ceylon.ide.common.completion {
    isLocation,
    completionManager
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    OccurrenceLocation
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Module,
    NamedArgumentList
}

shared object changeReferenceQuickFix {
    
    void addChangeReferenceProposal(QuickFixData data, String brokenName,
        Declaration dec) {
        
        value change 
               = platformServices.document.createTextChange {
            name = "Change Reference";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        variable value pkg = "";
        value problemOffset = data.problemOffset;
        variable value importsLength = 0;
        
        value importProposals 
                = CommonImportProposals {
                    document = data.document;
                    rootNode = data.rootNode;
                };

        if (dec.toplevel,
            !importProposals.isImported(dec),
            isInPackage(data.rootNode, dec)) {
            
            value pn = dec.container.qualifiedNameString;
            pkg = " in '" + pn + "'";
            if (!pn.empty,
                pn!=Module.languageModuleName,
                exists node = nodes.findNode {
                    node = data.rootNode;
                    tokens = null;
                    startOffset = problemOffset;
                }) {
                
                value ol = nodes.getOccurrenceLocation {
                    cu = data.rootNode;
                    node = node;
                    offset = problemOffset;
                };
                if (!isLocation(ol, OccurrenceLocation.\iIMPORT)) {
                    for (ie in importProposals.importEdits {
                        scope = data.node.scope;
                        dec
                    }) {
                        importsLength += ie.text.size;
                        change.addEdit(ie);
                    }
                }
            }
        }
        
        //Note: don't use problem.getLength() because it's wrong from the problem list
        change.addEdit(ReplaceEdit {
            start = problemOffset;
            length = brokenName.size;
            text = dec.name;
        });
        
        data.addQuickFix {
            description 
                    = "Change reference to '``dec.name``'``pkg``";
            qualifiedNameIsPath = true;
            change = change;
            selection = DefaultRegion {
                start = problemOffset + importsLength;
                length = dec.name.size;
            };
            declaration = dec;
        };
    }
    
    Boolean isInPackage(Tree.CompilationUnit cu, Declaration dec) 
            => !dec.unit.\ipackage==cu.unit.\ipackage;

    shared void addChangeReferenceProposals(QuickFixData data) {
        if (!data.useLazyFixes
            || data.node is Tree.QualifiedType
                          | Tree.QualifiedMemberOrTypeExpression) {
            findChangeReferenceProposals(data);
        }
    }
    
    shared void findChangeReferenceProposals(QuickFixData data) {
        if (exists id = nodes.getIdentifyingNode(data.node)) {
            if (exists brokenName = id.text, !brokenName.empty) {
                value dwps = completionManager.getProposals {
                    node = data.node;
                    scope = data.node.scope; //for declaration-style named args
                    prefix = "";
                    memberOp = false;
                    rootNode = data.rootNode;
                }.values();
                for (dwp in dwps) {
                    processProposal {
                        data = data;
                        brokenName = brokenName;
                        declaration = dwp.declaration;
                    };
                }
            }
        }
    }
    
    shared void addChangeArgumentReferenceProposals(QuickFixData data) {
        assert(exists id = nodes.getIdentifyingNode(data.node));
        String? brokenName = id.text;
        
        if (exists brokenName, !brokenName.empty) {
            if (is Tree.NamedArgument node = data.node) {
                variable value scope = node.scope;
                if (!(scope is NamedArgumentList)) {
                    scope = scope.scope; //for declaration-style named args
                }
                assert (is NamedArgumentList namedArgumentList = scope);
                if (exists parameterList = namedArgumentList.parameterList) {
                    for (parameter in parameterList.parameters) {
                        if (exists declaration = parameter.model) {
                            processProposal {
                                data = data;
                                brokenName = brokenName;
                                declaration = declaration;
                            };
                        }
                    }
                }
            }
        }
    }

    void processProposal(QuickFixData data, String brokenName, Declaration declaration) {

        if (exists name = declaration.name, brokenName!=name) {
            value nuc = name.first?.uppercase else false;
            value bnuc = brokenName.first?.uppercase else false;
            if (nuc == bnuc) {
                value similarity = distance.similarity(brokenName, name);
                //TODO: would it be better to just sort by distance, 
                //      and then select the 3 closest possibilities?
                if (similarity > 0.6) {
                    addChangeReferenceProposal {
                        data = data;
                        brokenName = brokenName;
                        dec = declaration;
                    };
                }
            }
        }
    }


}

NormalizedLevenshtein distance = NormalizedLevenshtein();