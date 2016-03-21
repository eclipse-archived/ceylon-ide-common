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

import java.util {
    Set,
    HashSet
}

// TODO extends InitializerProposal
shared interface CreateParameterQuickFix<IFile,Project,Document,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult> 
                & DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newCreateParameterProposal(Data data, String desc, Declaration dec, 
        Type? type, Region selection, Icons image, TextChange change, Integer exitPos);
    
    void addCreateParameterProposalInternal(Data data, String def, String desc, Icons image, Declaration dec,
        PhasedUnit unit, Tree.Declaration decNode, Tree.ParameterList paramList,
        Type? returnType, Set<Declaration> imports, Node node) {
        
        value change = newTextChange("Add Parameter", unit);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        value offset = paramList.stopIndex.intValue();
        value il = importProposals.applyImports(change, imports, unit.compilationUnit, doc);
        addEditToChange(change, newInsertEdit(offset, def));
        value exitPos = node.endIndex.intValue();
        
        value selection = correctionUtil.computeSelection(offset + il, def, newRegion);
        
        newCreateParameterProposal(data, "Add " + desc + " to '" + dec.name + "'",
            dec, returnType, selection, image, change, exitPos);
    }
    
    void addCreateParameterAndAttributeProposal(Data data, String pdef, String adef, String desc,
        Icons image, Declaration dec, PhasedUnit unit, Tree.Declaration decNode,
        Tree.ParameterList paramList, Tree.Body body, Type returnType) {
        
        value change = newTextChange("Add Attribute", unit);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        value offset = paramList.stopIndex.intValue();
        String indent;
        String indentAfter;
        Integer offset2;
        value statements = body.statements;
        if (statements.empty) {
            indentAfter = indents.getDefaultLineDelimiter(doc) + indents.getIndent(decNode, doc);
            indent = indentAfter + indents.defaultIndent;
            offset2 = body.startIndex.intValue() + 1;
        } else {
            value statement = statements.get(statements.size() - 1);
            indent = indents.getDefaultLineDelimiter(doc) + indents.getIndent(statement, doc);
            offset2 = statement.endIndex.intValue();
            indentAfter = "";
        }
        value decs = HashSet<Declaration>();
        value cu = unit.compilationUnit;
        importProposals.importType(decs, returnType, cu);
        value il = importProposals.applyImports(change, decs, cu, doc);
        addEditToChange(change, newInsertEdit(offset, pdef));
        addEditToChange(change, newInsertEdit(offset2, indent + adef + indentAfter));
        value exitPos = data.node.endIndex.intValue();
        
        value selection = correctionUtil.computeSelection(offset + il, pdef, newRegion);

        newCreateParameterProposal(data, "Add " + desc + " to '" + dec.name + "'", dec,
            returnType, selection, image, change, exitPos);
    }
    
    shared void addCreateParameterProposal(Data data, ValueFunctionDefinitionGenerator dg) {
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
                addCreateParameterProposalInternal(data, paramDef, paramDesc, Icons.addCorrection,
                    decl.declarationModel, phasedUnit, decl, paramList, dg.returnType, dg.getImports(), dg.node);
            }
        }
    }
    
    shared void addCreateParameterProposals(Data data) {
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

    void addCreateParameterProposalsInternal(Data data, variable String def, String desc, Declaration? typeDec, Type t) {
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
                value imports = HashSet<Declaration>();
                importProposals.importType(imports, t, phasedUnit.compilationUnit);
                addCreateParameterProposalInternal(data, def, desc, Icons.addCorrection, typeDec,
                    phasedUnit, decNode, paramList, t, imports, data.node);
            }
        }
    }
    
    void addCreateParameterAndAttributeProposals(Data data, variable String pdef, String adef, String desc, Declaration typeDec, Type t) {
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
