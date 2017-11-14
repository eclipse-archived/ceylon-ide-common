/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
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
    Tree,
    Node
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    TextChange
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
    Type,
    Functional,
    ClassOrInterface
}

shared object createParameterQuickFix {
    
    void addCreateParameterProposalInternal(QuickFixData data, String def, 
        String desc, Icons image, Declaration dec, PhasedUnit unit,
        Tree.Declaration decNode, Tree.ParameterList paramList,
        Type? returnType, CommonImportProposals importProposals, Node node) {
        
        value change = platformServices.document.createTextChange("Add Parameter", unit);
        change.initMultiEdit();
        value offset = paramList.stopIndex.intValue();
        value il = importProposals.apply(change);
        change.addEdit(InsertEdit(offset, def));
        value exitPos = node.endIndex.intValue();
        
        value selection = correctionUtil.computeSelection(offset + il, def, DefaultRegion);
        
        addProposal {
            data = data;
            desc = "Add ``desc`` to '``dec.name``'";
            dec = dec;
            returnType = returnType;
            selection = selection;
            image = image;
            change = change;
            exitPos = exitPos;
        };
    }
    
    void addProposal(QuickFixData data, String desc, Declaration dec,
        Type? returnType, DefaultRegion selection, Icons image,
        TextChange change, Integer exitPos) {
        
        value callback = void() {
            initializerQuickFix.applyWithLinkedMode {
                sourceDocument = change.document;
                change = change;
                selection = selection;
                type = returnType;
                unit = dec.unit;
                scope = dec.scope;
                exitPos = exitPos;
            };
        };
        data.addQuickFix {
            description = desc;
            change = callback;
            image = Icons.addCorrection;
        };
    }
    
    void addCreateParameterAndAttributeProposal(QuickFixData data, String pdef,
        String adef, String desc, Icons image, Declaration dec,
        PhasedUnit unit, Tree.Declaration decNode,
        Tree.ParameterList paramList, Tree.Body body, Type returnType) {
        
        value change = platformServices.document.createTextChange("Add Attribute", unit);
        change.initMultiEdit();
        value doc = change.document;
        value offset = paramList.stopIndex.intValue();
        String indent;
        String indentAfter;
        Integer offset2;
        value statements = body.statements;
        if (statements.empty) {
            indentAfter = doc.defaultLineDelimiter + doc.getIndent(decNode);
            indent = indentAfter + platformServices.document.defaultIndent;
            offset2 = body.startIndex.intValue() + 1;
        } else {
            value statement = statements.get(statements.size() - 1);
            indent = doc.defaultLineDelimiter + doc.getIndent(statement);
            offset2 = statement.endIndex.intValue();
            indentAfter = "";
        }
        value importProposals = CommonImportProposals(doc, data.rootNode);
        importProposals.importType(returnType);
        value il = importProposals.apply(change);
        change.addEdit(InsertEdit(offset, pdef));
        change.addEdit(InsertEdit(offset2, indent + adef + indentAfter));
        value exitPos = data.node.endIndex.intValue();
        
        value selection = correctionUtil.computeSelection(offset + il, pdef, DefaultRegion);

        addProposal {
            data = data;
            desc = "Add ``desc`` to '``dec.name``'";
            dec = dec;
            returnType = returnType;
            selection = selection;
            image = image;
            change = change;
            exitPos = exitPos;
        };
    }
    
    shared void addCreateParameterProposal(QuickFixData data, ValueFunctionDefinitionGenerator dg) {
        if (dg.brokenName.first?.lowercase else false, 
            exists decl = nodes.findDeclarationWithBody(dg.rootNode, dg.node), 
            exists dm = decl.declarationModel, !dm.actual, 
            exists paramList = getParameters(decl)) {
            value def = dg.generate("", "");
            //TODO: really ugly and fragile way to strip off the trailing ;
            value paramDef = (if (paramList.parameters.empty) then "" else ", ") + 
                    def.spanTo(def.size - (if (def.endsWith("{}")) then 3 else 1) - 1);
            value paramDesc = "parameter '" + dg.brokenName + "'";
            value u = dg.rootNode.unit;
            if (is AnyModifiableSourceFile u, 
                exists phasedUnit = u.phasedUnit) {
                value importProposals = CommonImportProposals(data.document, data.rootNode);
                dg.generateImports(importProposals);
                
                addCreateParameterProposalInternal {
                    data = data;
                    def = paramDef;
                    desc = paramDesc;
                    image = Icons.addCorrection;
                    dec = dm;
                    unit = phasedUnit;
                    decNode = decl;
                    paramList = paramList;
                    returnType = dg.returnType;
                    importProposals = importProposals;
                    node = dg.node;
                };
            }
        }
    }
    
    shared void addCreateParameterProposals(QuickFixData data) {
        value fav = FindInvocationVisitor(data.node);
        fav.visit(data.rootNode);
        if (is Tree.MemberOrTypeExpression prim 
                = fav.result?.primary, 
            exists pr = prim.target) {
            
            Type parameterType;
            String parameterName;
            switch (node = data.node)
            case (is Tree.Term) {
                if (exists tt = node.typeModel) {
                    //exists tn = tt.declaration.name) {
                    value pn = nodes.nameProposals {
                        node = node;
                        avoidClash = false;
                    }[0];
                            //escaping.toInitialLowercase(tn)
                            //    .replace("?", "")
                            //    .replace("[]", "");
                    parameterName 
                            = switch(pn)
                            case ("string") "text"
                            case ("true"|"false") "boolean" 
                            else pn;
                    parameterType = tt;
                }
                else {
                    return;
                }
            }
            case (is Tree.SpecifiedArgument) {
                if (exists se = node.specifierExpression, 
                    exists e = se.expression) {
                    parameterType = e.typeModel;
                }
                else {
                    return;
                }
                parameterName = node.identifier.text;
            }
            case (is Tree.TypedArgument) {
                parameterType = node.type.typeModel;
                parameterName = node.identifier.text;
            }
            else {
                return;
            }
            
            value dec = pr.declaration;
            value dt = data.node.unit.denotableType(parameterType);
            value defaultValue = correctionUtil.defaultValue(prim.unit, dt);
            value parameterTypeStr = dt.asSourceCodeString(prim.unit);
            value def = parameterTypeStr + " " + parameterName + " = " + defaultValue;
            value desc = "parameter '" + parameterName + "'";
            addCreateParameterProposalsInternal(data, def, desc, dec, dt);
            value pdef = parameterName + " = " + defaultValue;
            value adef = parameterTypeStr + " " + parameterName + ";";
            value padesc = "attribute '" + parameterName + "'";
            addCreateParameterAndAttributeProposals(data, pdef, adef, padesc, dec, dt);
        }
    }

    Tree.ParameterList? getParameters(Tree.Declaration decNode)
            => switch (decNode)
            case (is Tree.AnyClass) decNode.parameterList
            case (is Tree.AnyMethod) decNode.parameterLists[0]
            case (is Tree.Constructor) decNode.parameterList
            else null;

    void addCreateParameterProposalsInternal(QuickFixData data, 
        variable String def, String desc, Declaration? typeDec, Type t) {
        
        if (exists typeDec, is Functional typeDec, 
            is AnyModifiableSourceFile unit = typeDec.unit, 
            exists phasedUnit = unit.phasedUnit) {
            value fdv = FindDeclarationNodeVisitor(typeDec);
            correctionUtil.getRootNode(phasedUnit).visit(fdv);

            if (is Tree.Declaration decNode = fdv.declarationNode, 
                exists paramList = getParameters(decNode)) {

                if (!paramList.parameters.empty) {
                    def = ", " + def;
                }
                value importProposals = CommonImportProposals(data.document, phasedUnit.compilationUnit);
                importProposals.importType(t);

                addCreateParameterProposalInternal {
                    data = data;
                    def = def;
                    desc = desc;
                    image = Icons.addCorrection;
                    dec = typeDec;
                    unit = phasedUnit;
                    decNode = decNode;
                    paramList = paramList;
                    returnType = t;
                    importProposals = importProposals;
                    node = data.node;
                };
            }
        }
    }
    
    void addCreateParameterAndAttributeProposals(QuickFixData data, 
        variable String pdef, String adef, String desc, Declaration typeDec, Type t) {
        
        if (is ClassOrInterface typeDec, 
            is AnyModifiableSourceFile unit = typeDec.unit, 
            exists phasedUnit = unit.phasedUnit) {

            value fdv = FindDeclarationNodeVisitor(typeDec);
            correctionUtil.getRootNode(phasedUnit).visit(fdv);

            if (is Tree.Declaration decNode = fdv.declarationNode, 
                exists body = correctionUtil.getClassOrInterfaceBody(decNode), 
                exists paramList = getParameters(decNode)) {
                
                if (!paramList.parameters.empty) {
                    pdef = ", " + pdef;
                }
                addCreateParameterAndAttributeProposal { data = data;
                    pdef = pdef;
                    adef = adef;
                    desc = desc;
                    image = Icons.addCorrection;
                    dec = typeDec;
                    unit = phasedUnit;
                    decNode = decNode;
                    paramList = paramList;
                    body = body;
                    returnType = t;
                };
            }
        }
    }
}
