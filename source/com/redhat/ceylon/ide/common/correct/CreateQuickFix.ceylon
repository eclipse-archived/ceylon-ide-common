import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindContainerVisitor,
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Scope,
    Unit,
    Type,
    Interface,
    Class
}

// TODO extends InitializerProposal
shared interface CreateQuickFix<IFile,Project,Document,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,Document,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
                & DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData {

    shared formal CreateParameterQuickFix<IFile,Project,Document,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult> 
            createParameterQuickFix;

    shared formal void newCreateQuickFix(Data data, String desc,
        Scope scope, Unit unit, Type? returnType, Icons image,
        TextChange change, Integer exitPos, Region selection);
    
    void addCreateMemberProposal(Data data, DefinitionGenerator dg, 
        Declaration typeDec, PhasedUnit unit, Tree.Declaration decNode, 
        Tree.Body body, Tree.Statement? statement) {
        
        value change = newTextChange("Create Member", unit);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        String indentBefore;
        variable String indentAfter;
        String indent;
        Integer offset;
        value statements = body.statements;
        value delim = indents.getDefaultLineDelimiter(doc);
        if (statements.empty) {
            value bodyIndent = indents.getIndent(decNode, doc);
            indent = bodyIndent + indents.defaultIndent;
            indentBefore = delim + indent;
            try {
                value singleLineBody = 
                        getLineOfOffset(doc, body.startIndex.intValue())
                        == getLineOfOffset(doc, body.stopIndex.intValue());
                indentAfter = 
                        singleLineBody then delim + bodyIndent else "";
            } catch (e) {
                e.printStackTrace();
                indentAfter = delim;
            }
            offset = body.startIndex.intValue() + 1;
        } else {
            variable Tree.Statement st;
            if (exists statement, statement.unit==body.unit,
                statement.startIndex.intValue() 
                        >= body.startIndex.intValue(),
                statement.endIndex.intValue() 
                        <= body.endIndex.intValue()) {
                
                st = statements.get(0);
                for (s in statements) {
                    if (statement.startIndex.intValue() >= s.startIndex.intValue(),
                        statement.endIndex.intValue() <= s.endIndex.intValue()) {
                        
                        st = s;
                    }
                }
                indent = indents.getIndent(st, doc);
                indentBefore = "";
                indentAfter = delim + indent;
                offset = st.startIndex.intValue();
            } else {
                st = statements.get(statements.size() - 1);
                indent = indents.getIndent(st, doc);
                indentBefore = delim + indent;
                indentAfter = "";
                offset = st.endIndex.intValue();
            }
        }
        value generated = if (is Interface typeDec)
        then dg.generateSharedFormal(indent, delim)
        else dg.generateShared(indent, delim);
        value def = indentBefore + generated + indentAfter;
        value il = importProposals.applyImports {
            change = change;
            declarations = dg.getImports();
            rootNode = unit.compilationUnit;
            doc = doc;
        };
        addEditToChange(change, newInsertEdit(offset, def));
        
        newCreateQuickFix {
            data = data;
            desc = "Create " + memberKind(dg) + 
                    " in '" + typeDec.name + "'";
            scope = body.scope;
            unit = body.unit;
            returnType = dg.returnType;
            image = dg.image;
            change = change;
            exitPos = dg.node.endIndex.intValue();
            selection 
                    = if (dg is ObjectClassDefinitionGenerator)
                    then newRegion(offset + il, 0)
                    else correctionUtil.computeSelection {
                        offset = offset + il;
                        def = def;
                        newRegion = newRegion;
                    };
        };
    }
    
    String memberKind(DefinitionGenerator dg) {
        value desc = dg.description;
        if (desc.startsWith("constructor")) {
            return desc;
        }
        else if (desc.startsWith("function")) {
            return "method" + desc.spanFrom(8);
        }
        else if (desc.startsWith("value")) {
            return "attribute" + desc.spanFrom(5);
        }
        else if (desc.startsWith("class")) {
            return "member class" + desc.spanFrom(5);
        }
        return desc;
    }
    
    void addCreateProposal(Data data, Boolean local, 
        DefinitionGenerator dg, PhasedUnit unit, 
        Tree.Statement statement) {
        
        value change = newTextChange {
            desc = local then "Create Local" else "Create Toplevel";
            u = unit;
        };
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        value indent = indents.getIndent(statement, doc);
        value offset = statement.startIndex.intValue();
        value delim = indents.getDefaultLineDelimiter(doc);
        value rootNode = unit.compilationUnit;
        value il = importProposals.applyImports {
            change = change;
            declarations = dg.getImports();
            rootNode = rootNode;
            doc = doc;
        };
        value gen = dg.generate(indent, delim) + delim + indent;
        value def = local then gen else gen + delim;
        addEditToChange(change, 
            newInsertEdit {
                position = offset;
                text = def;
            });
        value desc = 
                (local then "Create local " else "Create toplevel ") 
                    + dg.description;
        value scope = 
                local then statement.scope else rootNode.unit.\ipackage;
        
        newCreateQuickFix {
            data = data;
            desc = desc;
            scope = scope;
            unit = rootNode.unit;
            returnType = dg.returnType;
            image = dg.image;
            change = change;
            exitPos = dg.node.endIndex.intValue();
            selection 
                    = if (dg is ObjectClassDefinitionGenerator)
                    then newRegion(offset + il, 0)
                    else correctionUtil.computeSelection {
                        offset = offset + il;
                        def = def;
                        newRegion = newRegion;
                    };
        };
    }
    
    void addCreateMemberProposals(Data data, DefinitionGenerator dg,
        Tree.QualifiedMemberOrTypeExpression qmte, Tree.Statement? statement) {
        
        if (exists typeDec
            = if (is Tree.BaseTypeExpression|Tree.QualifiedTypeExpression
                    type = qmte.primary)
            then type.declaration
            else qmte.primary.typeModel.declaration) {
            addCreateMemberProposals2(data, dg, typeDec, statement);
        }
    }
    
    void addCreateMemberProposals2(Data data, DefinitionGenerator dg,
        Declaration? typeDec, Tree.Statement? statement) {
        
        if (exists typeDec, 
            typeDec is Class || 
            typeDec is Interface && dg.isFormalSupported, 
            is AnyModifiableSourceFile unit = typeDec.unit, 
            exists phasedUnit = unit.phasedUnit) {
            value fdv = FindDeclarationNodeVisitor(typeDec);
            correctionUtil.getRootNode(phasedUnit).visit(fdv);
            
            if (is Tree.Declaration decNode = fdv.declarationNode,
                exists body = correctionUtil.getClassOrInterfaceBody(decNode)) {
                addCreateMemberProposal(data, dg, typeDec, phasedUnit, decNode, body, statement);
            }
        }
    }
    
    void addCreateLocalProposals(Data data, DefinitionGenerator dg) {
        if (exists statement 
                = nodes.findStatement(dg.rootNode, dg.node), 
            is AnyModifiableSourceFile unit = dg.rootNode.unit, 
            exists phasedUnit = unit.phasedUnit) {
            addCreateProposal(data, true, dg, phasedUnit, statement);
        }
    }

    void addCreateToplevelProposals(Data data, DefinitionGenerator dg) {
        if (exists statement 
                = nodes.findTopLevelStatement(dg.rootNode, dg.node), 
            is AnyModifiableSourceFile unit = dg.rootNode.unit, 
            exists phasedUnit = unit.phasedUnit) {
            addCreateProposal(data, false, dg, phasedUnit, statement);
        }
    }
    
    shared void addCreateProposals(Data data, IFile file, Node node = data.node) {
        assert (is Tree.MemberOrTypeExpression node);
        
        if (exists idNode = nodes.getIdentifyingNode(node), 
            exists brokenName = idNode.text, 
            !brokenName.empty) {
            if (exists vfdg = createValueFunctionDefinitionGenerator {
                brokenName = brokenName;
                node = node;
                rootNode = data.rootNode;
                importProposals = importProposals;
            }) {
                if (is Tree.BaseMemberExpression node, 
                    node.identifier.token.type != CeylonLexer.\iAIDENTIFIER) {
                    createParameterQuickFix.addCreateParameterProposal(data, vfdg);
                }
                addCreateProposalsInternal {
                    data = data;
                    file = file;
                    smte = node;
                    dg = vfdg;
                };
            }
            if (exists ocdg = createObjectClassDefinitionGenerator {
                brokenName = brokenName;
                node = node;
                rootNode = data.rootNode;
                importProposals = importProposals;
                indents = indents;
                completionManager = completionManager;
            }) {
                addCreateProposalsInternal {
                    data = data;
                    file = file;
                    smte = node;
                    dg = ocdg;
                };
            }
        }
    }
    
    void addCreateProposalsInternal(Data data, IFile file, 
        Tree.MemberOrTypeExpression smte, DefinitionGenerator dg) {
        if (is Tree.QualifiedMemberOrTypeExpression smte) {
            addCreateMemberProposals(data, dg, smte, 
                nodes.findStatement(data.rootNode, smte));
        } else {
            if (!(dg.node is Tree.ExtendedTypeExpression)) {
                addCreateLocalProposals(data, dg);
                variable value container = findClassContainer(data.rootNode, smte);
                if (exists con = container, con != smte.scope) {
                    while (exists _container = container) {
                        addCreateMemberProposals2(data, dg, _container, 
                            nodes.findStatement(data.rootNode, smte));
                        if (is Declaration innerCon = _container.container) {
                            value outerContainer = innerCon;
                            container = findClassContainer2(outerContainer);
                        } else {
                            break;
                        }
                    }
                }
            }
            addCreateToplevelProposals(data, dg);
            // TODO addCreateInNewUnitProposal(proposals, dg, file, rootNode);
        }
    }
    
    ClassOrInterface? findClassContainer(Tree.CompilationUnit cu, Node node) {
        value fcv = FindContainerVisitor(node);
        fcv.visit(cu);
        value declaration = fcv.declaration;
        if (declaration?.equals(node) else true) {
            return null;
        }
        if (is Tree.ClassOrInterface declaration) {
            return declaration.declarationModel;
        }
        if (is Tree.MethodDefinition declaration) {
            return findClassContainer2(declaration.declarationModel);
        }
        if (is Tree.ObjectDefinition declaration) {
            return findClassContainer2(declaration.declarationModel);
        }
        return null;
    }
    
    ClassOrInterface? findClassContainer2(variable Declaration? declarationModel) {
        while (true) {
            if (exists m = declarationModel) {
                if (is ClassOrInterface m) {
                    return m;
                }
                value container = m.container;
                if (is Declaration container) {
                    declarationModel = container;
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
    }
}
