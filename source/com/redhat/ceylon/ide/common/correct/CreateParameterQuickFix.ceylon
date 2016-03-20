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
    escaping,
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type,
    Reference,
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
        value res = fav.result;
        if (!exists res) {
            return;
        }

        value prim = res.primary;
        if (is Tree.MemberOrTypeExpression prim) {
            value mte = prim;
            Reference? pr = mte.target;
            if (exists pr) {
                value d = pr.declaration;
                variable Type? t = null;
                variable String? parameterName = null;
                if (is Tree.Term term = data.node) {
                    t = term.typeModel;
                    if (exists _t = t) {
                        parameterName = _t.declaration.name;
                        if (exists pn = parameterName) {
                            parameterName = escaping.toInitialLowercase(pn)
                                    .replace("?", "")
                                    .replace("[]", "");
                            if (exists pn2 = parameterName, pn2 == "string") {
                                parameterName = "text";
                            }
                        }
                    }
                } else if (is Tree.SpecifiedArgument sa = data.node) {
                    if (exists se = sa.specifierExpression) {
                        if (exists e = se.expression) {
                            t = e.typeModel;
                        }
                    }
                    parameterName = sa.identifier.text;
                } else if (is Tree.TypedArgument ta = data.node) {
                    t = ta.type.typeModel;
                    parameterName = ta.identifier.text;
                }
                if (exists _t = t, exists pn = parameterName) {
                    t = data.node.unit.denotableType(_t);
                    value defaultValue = correctionUtil.defaultValue(prim.unit, t);
                    value parameterType = _t.asString();
                    value def = parameterType + " " + pn + " = " + defaultValue;
                    value desc = "parameter '" + pn + "'";
                    addCreateParameterProposalsInternal(data, def, desc, d, _t);
                    value pdef = pn + " = " + defaultValue;
                    value adef = parameterType + " " + pn + ";";
                    value padesc = "attribute '" + pn + "'";
                    addCreateParameterAndAttributeProposals(data, pdef, adef, padesc, d, _t);
                }
            }
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
