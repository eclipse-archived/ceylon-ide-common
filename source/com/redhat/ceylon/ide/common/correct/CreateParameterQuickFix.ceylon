import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    Visitor
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type,
    Functional,
    ClassOrInterface
}

// TODO extends InitializerProposal
shared object createParameterQuickFix {
    
    void addCreateParameterProposalInternal(QuickFixData data, String def, String desc, Icons image, Declaration dec,
        PhasedUnit unit, Tree.Declaration decNode, Tree.ParameterList paramList,
        Type? returnType, CommonImportProposals importProposals, Node node) {
        
        value change = platformServices.createTextChange("Add Parameter", unit);
        change.initMultiEdit();
        value offset = paramList.stopIndex.intValue();
        value il = importProposals.apply(change);
        change.addEdit(InsertEdit(offset, def));
        value exitPos = node.endIndex.intValue();
        
        value selection = correctionUtil.computeSelection(offset + il, def, DefaultRegion);
        
        data.addCreateParameterProposal("Add " + desc + " to '" + dec.name + "'",
            dec, returnType, selection, image, change, exitPos);
    }
    
    void addCreateParameterAndAttributeProposal(QuickFixData data, String pdef, String adef, String desc,
        Icons image, Declaration dec, PhasedUnit unit, Tree.Declaration decNode,
        Tree.ParameterList paramList, Tree.Body body, Type returnType) {
        
        value change = platformServices.createTextChange("Add Attribute", unit);
        change.initMultiEdit();
        value doc = change.document;
        value offset = paramList.stopIndex.intValue();
        String indent;
        String indentAfter;
        Integer offset2;
        value statements = body.statements;
        if (statements.empty) {
            indentAfter = doc.defaultLineDelimiter + doc.getIndent(decNode);
            indent = indentAfter + doc.defaultIndent;
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

        data.addCreateParameterProposal("Add " + desc + " to '" + dec.name + "'", dec,
            returnType, selection, image, change, exitPos);
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
                addCreateParameterProposalInternal(data, paramDef, paramDesc, Icons.addCorrection,
                    decl.declarationModel, phasedUnit, decl, paramList, dg.returnType, importProposals, dg.node);
            }
        }
    }
    
    shared void addCreateParameterProposals(QuickFixData data) {
        value fav = FindInvocationVisitor(data.node);
        (fav of Visitor).visit(data.rootNode);
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

    Tree.ParameterList? getParameters(Tree.Declaration decNode) {
        if (is Tree.AnyClass decNode) {
            value ac = decNode;
            return ac.parameterList;
        } else if (is Tree.AnyMethod decNode) {
            value am = decNode;
            value pls = am.parameterLists;
            return pls[0];
        } else if (is Tree.Constructor decNode) {
            value c = decNode;
            return c.parameterList;
        }
        return null;
    }

    void addCreateParameterProposalsInternal(QuickFixData data, variable String def, String desc, Declaration? typeDec, Type t) {
        if (exists typeDec, is Functional typeDec, 
            is AnyModifiableSourceFile unit 
                    = (typeDec of Declaration).unit, 
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
                addCreateParameterProposalInternal(data, def, desc, Icons.addCorrection, typeDec,
                    phasedUnit, decNode, paramList, t, importProposals, data.node);
            }
        }
    }
    
    void addCreateParameterAndAttributeProposals(QuickFixData data, variable String pdef, String adef, String desc, Declaration typeDec, Type t) {
        if (is ClassOrInterface typeDec, 
            is AnyModifiableSourceFile unit 
                    = (typeDec of Declaration).unit, 
            exists phasedUnit = unit.phasedUnit) {
            value fdv = FindDeclarationNodeVisitor(typeDec);
            correctionUtil.getRootNode(phasedUnit).visit(fdv);
            if (is Tree.Declaration decNode = fdv.declarationNode, 
                exists body = correctionUtil.getClassOrInterfaceBody(decNode), 
                exists paramList = getParameters(decNode)) {
                if (!paramList.parameters.empty) {
                    pdef = ", " + pdef;
                }
                addCreateParameterAndAttributeProposal(data, pdef, adef, desc, 
                    Icons.addCorrection, typeDec, phasedUnit, 
                    decNode, paramList, body, t);
            }
        }
    }
}
