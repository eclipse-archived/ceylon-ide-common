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
    Tree
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object createEnumQuickFix {
    
    shared void addCreateEnumProposal(QuickFixData data) {
        value node = data.node;
        value rootNode = data.rootNode;
        value idn = nodes.getIdentifyingNode(node);
        if (!exists idn) {
            return;
        }

        value brokenName = idn.text;
        if (brokenName.empty) {
            return;
        }
        value dec = nodes.findDeclaration(rootNode, node);
        if (is Tree.ClassDefinition dec) {
            value cd = dec;
            if (exists c = cd.caseTypes) {
                if (cd.caseTypes.types.contains(node)) {
                    addCreateEnumProposalInternal(
                        "class " + brokenName + parameters(cd.typeParameterList)
                                + parameters2(cd.parameterList) + " extends "
                                + cd.declarationModel.name + parameters(cd.typeParameterList)
                                + arguments(cd.parameterList) + " {}",
                        "class '" + brokenName + parameters(cd.typeParameterList)
                                + parameters2(cd.parameterList) + "'",
                        Icons.classes, rootNode, cd, data);
                }
                if (cd.caseTypes.baseMemberExpressions.contains(node)) {
                    addCreateEnumProposalInternal(
                        "object " + brokenName + " extends " + cd.declarationModel.name
                                + parameters(cd.typeParameterList) + arguments(cd.parameterList)
                                + " {}", "object '" + brokenName + "'",
                        Icons.attributes, rootNode, cd, data);
                }
            }
        }
        if (is Tree.InterfaceDefinition dec) {
            value cd = dec;
            if (exists c = cd.caseTypes) {
                if (cd.caseTypes.types.contains(node)) {
                    addCreateEnumProposalInternal(
                        "interface " + brokenName + parameters(cd.typeParameterList)
                                + " satisfies " + cd.declarationModel.name
                                + parameters(cd.typeParameterList) + " {}",
                        "interface '" + brokenName + parameters(cd.typeParameterList) + "'",
                        Icons.interfaces, rootNode, cd, data);
                }
                if (cd.caseTypes.baseMemberExpressions.contains(node)) {
                    addCreateEnumProposalInternal( 
                        "object " + brokenName + " satisfies "
                                + cd.declarationModel.name + parameters(cd.typeParameterList)
                                + " {}", "object '" + brokenName + "'",
                        Icons.attributes, rootNode, cd, data);
                }
            }
        }
    }
    
    void addCreateEnumProposalInternal(String def, String desc, Icons image,
        Tree.CompilationUnit cu, Tree.TypeDeclaration cd, QuickFixData data) {
        
        if (is AnyModifiableSourceFile unit = cu.unit, 
            exists phasedUnit = unit.phasedUnit) {
            addCreateEnumProposalInternal2(def, desc, image, phasedUnit, cd, data);
        }
    }
    
    void addCreateEnumProposalInternal2(String def, String desc, Icons image,
        PhasedUnit unit, Tree.Statement statement, QuickFixData data) {
        
        value change = platformServices.document.createTextChange("Create Enumerated", unit);
        value doc = change.document;
        value indent = doc.getIndent(statement);
        variable value s = indent + def + doc.defaultLineDelimiter;
        variable value offset = statement.endIndex.intValue() + 1;
        
        if (offset > doc.size) {
            offset = doc.size;
            s = doc.defaultLineDelimiter + s;
        }
        
        change.initMultiEdit();
        change.addEdit(InsertEdit(offset, s));
        
        data.addQuickFix { 
            description = "Create enumerated " + desc;
            change = change;
            selection = DefaultRegion(offset + (def.firstInclusion("{}") else -1) + 1, 0);
            image = image;
        };
    }
    
    String parameters(Tree.TypeParameterList? tpl) {
        value result = StringBuilder();
        if (exists tpl, !tpl.typeParameterDeclarations.empty) {
            result.append("<");
            value len = tpl.typeParameterDeclarations.size();
            variable value i = 0;
            for (p in tpl.typeParameterDeclarations) {
                result.append(p.identifier.text);
                if (++i < len) {
                    result.append(", ");
                }
            }
            result.append(">");
        }
        return result.string;
    }
    
    String parameters2(Tree.ParameterList? pl) {
        value result = StringBuilder();
        if (pl?.parameters?.empty else true) {
            result.append("()");
        } else {
            assert(exists pl);
            result.append("(");
            value len = pl.parameters.size();
            variable value i = 0;
            for (Tree.Parameter? p in pl.parameters) {
                if (exists p) {
                    switch (p)
                    case (is Tree.ParameterDeclaration) {
                        value td = (p).typedDeclaration;
                        result.append(td.type.typeModel.asString()).append(" ").append(td.identifier.text);
                    }
                    case (is Tree.InitializerParameter) {
                        result.append(p.parameterModel.type.asString()).append(" ").append((p).identifier.text);
                    }
                    else {}
                }
                if (++i < len) {
                    result.append(", ");
                }
            }
            result.append(")");
        }
        return result.string;
    }
    
    String arguments(Tree.ParameterList? pl) {
        value result = StringBuilder();
        if (pl?.parameters?.empty else true) {
            result.append("()");
        } else {
            assert (exists pl);
            result.append("(");
            value len = pl.parameters.size();
            variable value i = 0;
            for (Tree.Parameter? p in pl.parameters) {
                if (exists p) {
                    Tree.Identifier id;
                    switch (p)
                    case (is Tree.InitializerParameter) {
                        id = p.identifier;
                    }
                    case (is Tree.ParameterDeclaration) {
                        id = p.typedDeclaration.identifier;
                    }
                    else {
                        continue;
                    }
                    result.append(id.text);
                }
                if (++i < len) {
                    result.append(", ");
                }
            }
            result.append(")");
        }
        return result.string;
    }
}
