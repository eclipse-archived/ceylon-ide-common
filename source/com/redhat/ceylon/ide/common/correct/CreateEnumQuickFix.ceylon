import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.util {
    nodes
}

shared interface CreateEnumQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionResult>
        satisfies DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
                & AbstractQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionResult>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData {
    
    shared formal void consumeNewQuickFix(String desc, Icons image,
        Integer offset, TextChange change, Data data);
    
    shared formal Integer getDocLength(Document doc);
    
    shared void addCreateEnumProposal(Data data) {
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
        Tree.CompilationUnit cu, Tree.TypeDeclaration cd, Data data) {
        
        if (is AnyModifiableSourceFile unit = cu.unit, 
            exists phasedUnit = unit.phasedUnit) {
            addCreateEnumProposalInternal2(def, desc, image, phasedUnit, cd, data);
        }
    }
    
    void addCreateEnumProposalInternal2(String def, String desc, Icons image,
        PhasedUnit unit, Tree.Statement statement, Data data) {
        
        value change = newTextChange("Create Enumerated", unit);
        value doc = getDocumentForChange(change);
        value indent = indents.getIndent(statement, doc);
        variable value s = indent + def + indents.getDefaultLineDelimiter(doc);
        variable value offset = statement.endIndex.intValue() + 1;
        
        if (offset > getDocLength(doc)) {
            offset = getDocLength(doc);
            s = indents.getDefaultLineDelimiter(doc) + s;
        }
        
        initMultiEditChange(change);
        addEditToChange(change, newInsertEdit(offset, s));
        
        consumeNewQuickFix("Create enumerated " + desc, image,
            offset + (def.firstInclusion("{}") else -1) + 1, change, data);
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
                    if (is Tree.ParameterDeclaration p) {
                        value td = (p).typedDeclaration;
                        result.append(td.type.typeModel.asString()).append(" ").append(td.identifier.text);
                    } else if (is Tree.InitializerParameter p) {
                        result.append(p.parameterModel.type.asString()).append(" ").append((p).identifier.text);
                    }
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
                    if (is Tree.InitializerParameter p) {
                        id = (p).identifier;
                    } else if (is Tree.ParameterDeclaration p) {
                        id = (p).typedDeclaration.identifier;
                    } else {
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
