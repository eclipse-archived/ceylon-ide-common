import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.correct {
    DocumentChanges
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit
}
import com.redhat.ceylon.ide.common.platform {
    platformServices
}
import com.redhat.ceylon.ide.common.typechecker {
    AnyProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindReferencesVisitor,
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    FunctionOrValue,
    Setter,
    TypeAlias,
    ClassOrInterface,
    Unit,
    TypeParameter,
    Generic
}

import java.util {
    JList=List,
    HashSet,
    Set
}

import org.antlr.runtime {
    CommonToken,
    Token
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}

shared interface InlineRefactoring<ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, Change>
        satisfies AbstractRefactoring<Change>
                & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        given InsertEdit satisfies TextEdit {
    
    shared interface InlineData satisfies EditorData {
        shared formal Declaration declaration;
        shared formal Boolean justOne;
        shared formal Boolean delete;
        shared formal IDocument doc;
    }
    
    shared formal actual InlineData editorData;
    shared formal TextChange newFileChange(PhasedUnit pu);
    shared formal TextChange newDocChange(IDocument doc);
    shared formal void addChangeToChange(Change change, TextChange tc);

    shared Boolean isReference =>
            let (node = editorData.node)
            !node is Tree.Declaration 
            && nodes.getIdentifyingNode(node) is Tree.Identifier;
    
    shared actual Boolean enabled {
        value declaration = editorData.declaration;

        if (inSameProject(declaration)) {
            if (is FunctionOrValue declaration) {
                value fov = declaration;
                return !fov.parameter 
                        && !(fov is Setter) 
                        && !fov.default 
                        && !fov.formal 
                        && !fov.native 
                        && (fov.typeDeclaration exists) 
                        && (!fov.typeDeclaration.anonymous) 
                        && (fov.toplevel 
                            || !fov.shared 
                            || (!fov.formal && !fov.default && !fov.actual))
                        && (!fov.unit.equals(rootNode.unit) 
                            //not a Destructure
                            || !(getDeclarationNode(rootNode) is Tree.Variable));
                //TODO: && !declaration is a control structure variable 
                //TODO: && !declaration is a value with lazy init
            } else if (is TypeAlias declaration) {
                return true;
            } else if (is ClassOrInterface declaration) {
                return declaration.\ialias;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    shared actual Integer countReferences(Tree.CompilationUnit cu) { 
        value vis = FindReferencesVisitor(editorData.declaration);
        cu.visit(vis);
        return vis.nodeSet.size();
    }

    name => "Inline";

    "Returns a single error or a sequence of warnings."
    shared String|String[] checkAvailability() {
        value declaration = editorData.declaration;
        value unit = declaration.unit;
        value declarationUnit = if (is CeylonUnit cu = unit)
            then cu.phasedUnit?.compilationUnit
            else null;
        
        if (!exists declarationUnit) {
            return "Compilation unit not found";
        }
        
        value declarationNode = getDeclarationNode(declarationUnit);
        if (is Tree.AttributeDeclaration declarationNode,
            !declarationNode.specifierOrInitializerExpression exists) {

            return "Cannot inline forward declaration: " + declaration.name;
        }
        if (is Tree.MethodDeclaration declarationNode,
            !declarationNode.specifierExpression exists) {

            return "Cannot inline forward declaration: " + declaration.name;            
        }
        
        if (is Tree.AttributeGetterDefinition declarationNode) {
            value getterDefinition = declarationNode;
            value statements = getterDefinition.block.statements;
            if (statements.size() != 1) {
                return "Getter body is not a single statement: " + declaration.name;
            }
            
            if (!(statements.get(0) is Tree.Return)) {
                return "Getter body is not a return statement: " + declaration.name;
            }
        }
        
        if (is Tree.MethodDefinition declarationNode) {
            value statements = declarationNode.block.statements;
            if (statements.size() != 1) {
                return "Function body is not a single statement: " + declaration.name;
            }
            
            value statement = statements.get(0);
            if (declarationNode.type is Tree.VoidModifier) {
                if (!statement is Tree.ExpressionStatement) {
                    return "Function body is not an expression: " + declaration.name;
                }
            } else if (!statement is Tree.Return) {
                return "Function body is not a return statement: " + declaration.name;
            }
        }
        
        value warnings = ArrayList<String>();
        
        if (is Tree.AnyAttribute declarationNode) {
            value attribute = declarationNode;
            if (attribute.declarationModel.variable) {
                warnings.add("Inlined value is variable");
            }
        }
        
        if (exists declarationNode) {
            declarationNode.visit(object extends Visitor() {
                shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
                    super.visit(that);
                    if (exists dec = that.declaration) {
                        if (declaration.shared, !dec.shared, !dec.parameter) {
                            warnings.add("Definition contains reference to " 
                                          + "unshared declaration: " + dec.name);
                        }
                    } else {
                        warnings.add("Definition contains unresolved reference");
                    }
                }
            });
        }
        
        return warnings.sequence();
    }

    shared actual Change build(Change cc) {
        variable Tree.CompilationUnit? declarationUnit = null;
        variable JList<CommonToken>? declarationTokens = null;
        value editorTokens = editorData.tokens;
        value declaration = editorData.declaration;
        
        value unit = declaration.unit;
        if (searchInEditor()) {
            if (editorData.rootNode.unit.equals(unit)) {
                declarationUnit = editorData.rootNode;
                declarationTokens = editorTokens;
            }
        }
        
        if (!exists _ = declarationUnit) {
            for (pu in getAllUnits()) {
                if (pu.unit.equals(unit)) {
                    declarationUnit = pu.compilationUnit;
                    declarationTokens = pu.tokens;
                    break;
                }
            }
        }
        
        if (exists declUnit = declarationUnit,
            exists declTokens = declarationTokens,
            is Tree.Declaration declarationNode = getDeclarationNode(declUnit)) {

            value term = getInlinedTerm(declarationNode);
        
            for (pu in getAllUnits()) {
                if (searchInFile(pu), affectsUnit(pu.unit)) {
                    assert (is AnyProjectPhasedUnit ppu = pu);
                    value tfc = newFileChange(ppu);
                    value cu = pu.compilationUnit;
                    inlineInFile(tfc, cc, declarationNode, declUnit, term,
                        declTokens, cu, pu.tokens);
                }
            }

            if (searchInEditor(), affectsUnit(editorData.rootNode.unit)) {
                value dc = newDocChange(editorData.doc);
                inlineInFile(dc, cc, declarationNode, declUnit, term, declTokens,
                    editorData.rootNode, editorTokens);
            }
        }
        
        return cc;
    }

    Tree.StatementOrArgument? getDeclarationNode(Tree.CompilationUnit declarationUnit) {
        value fdv = FindDeclarationNodeVisitor(editorData.declaration);
        declarationUnit.visit(fdv);
        return fdv.declarationNode;
    }

    Boolean affectsUnit(Unit unit) {
        return editorData.delete && unit == editorData.declaration.unit
                || !editorData.justOne  
                || unit == editorData.node.unit;
    }

    value importProposals => platformServices.importProposals<Nothing,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange>();

    Boolean addImports(TextChange change, Tree.Declaration declarationNode,
        Tree.CompilationUnit cu) {
        
        value decPack = declarationNode.unit.\ipackage;
        value filePack = cu.unit.\ipackage;
        variable Boolean importedFromDeclarationPackage = false;

        class AddImportsVisitor(already) extends Visitor() {
            Set<Declaration> already;
            
            shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
                super.visit(that);
                if (exists dec = that.declaration) {
                    importProposals.importDeclaration(already, dec, cu);
                    value refPack = dec.unit.\ipackage;
                    importedFromDeclarationPackage = importedFromDeclarationPackage
                            || refPack.equals(decPack)
                            && !decPack.equals(filePack); //unnecessary
                }
            }
        }
        
        value already = HashSet<Declaration>();
        value aiv = AddImportsVisitor(already);
        declarationNode.visit(aiv);
        value dnd = declarationNode.declarationModel;
        importProposals.applyImports(change, already, cu, editorData.doc, dnd);
        return importedFromDeclarationPackage;
    }

    void inlineInFile(TextChange tfc, Change parentChange, 
        Tree.Declaration declarationNode, Tree.CompilationUnit declarationUnit, 
        Node term, JList<CommonToken> declarationTokens, Tree.CompilationUnit cu,
        JList<CommonToken> tokens) {
        
        initMultiEditChange(tfc);
        inlineReferences(declarationNode, declarationUnit, term, 
            declarationTokens, cu, tokens, tfc);
        value inlined = hasChildren(tfc);
        deleteDeclaration(declarationNode, declarationUnit, cu, tokens, tfc);
        value importsAdded = inlined && addImports(tfc, declarationNode, cu);
        
        deleteImports(tfc, declarationNode, cu, tokens, importsAdded);
        if (hasChildren(tfc)) {
            addChangeToChange(parentChange, tfc);
        }
    }

    void deleteImports(TextChange tfc, Tree.Declaration declarationNode, 
        Tree.CompilationUnit cu, JList<CommonToken> tokens,
        Boolean importsAddedToDeclarationPackage) {
        
        if (exists il = cu.importList) {
            for (i in il.imports) {
                value list = i.importMemberOrTypeList.importMemberOrTypes;
                for (imt in list) {
                    value dnd = declarationNode.declarationModel;
                    if (exists d = imt.declarationModel, d == dnd) {
                        if (list.size() == 1, !importsAddedToDeclarationPackage) {
                            //delete the whole import statement
                            addEditToChange(tfc, newDeleteEdit(i.startIndex.intValue(),
                                i.distance.intValue()));
                        } else {
                            //delete just the item in the import statement...
                            addEditToChange(tfc, newDeleteEdit(imt.startIndex.intValue(),
                                imt.distance.intValue()));
                            //...along with a comma before or after
                            value ti = nodes.getTokenIndexAtCharacter(tokens,
                                imt.startIndex.intValue());
                            
                            variable CommonToken prev = tokens.get(ti - 1);
                            if (prev.channel == CommonToken.\iHIDDEN_CHANNEL) {
                                prev = tokens.get(ti - 2);
                            }
                            
                            variable CommonToken next = tokens.get(ti + 1);
                            if (next.channel == CommonToken.\iHIDDEN_CHANNEL) {
                                next = tokens.get(ti + 2);
                            }
                            
                            if (prev.type == CeylonLexer.\iCOMMA) {
                                addEditToChange(tfc, newDeleteEdit(prev.startIndex,
                                    imt.startIndex.intValue() - prev.startIndex));
                            } else if (next.type == CeylonLexer.\iCOMMA) {
                                addEditToChange(tfc, newDeleteEdit(imt.endIndex.intValue(),
                                    next.stopIndex - imt.endIndex.intValue() + 1));
                            }
                        }
                    }
                }
            }
        }
    }
    
    void deleteDeclaration(Tree.Declaration declarationNode,
        Tree.CompilationUnit declarationUnit, Tree.CompilationUnit cu,
        JList<CommonToken> tokens, TextChange tfc) {
        
        if (editorData.delete) {
            value unit = declarationUnit.unit;
            if (cu.unit.equals(unit)) {

                variable value from = declarationNode.token;
                value anns = declarationNode.annotationList;
                if (!anns.annotations.empty) {
                    from = anns.annotations.get(0).token;
                }
                
                value prevIndex = from.tokenIndex - 1;
                if (prevIndex >= 0, 
                    exists tok = tokens.get(prevIndex),
                    tok.channel == Token.\iHIDDEN_CHANNEL) {
                    
                    from = tok;
                }
                
                if (is CommonToken t = from) {
                    addEditToChange(tfc, newDeleteEdit(t.startIndex,
                        declarationNode.endIndex.intValue() - t.startIndex));
                }
            }
        }
    }

    Node getInlinedTerm(Tree.Declaration declarationNode) {
        if (is Tree.AttributeDeclaration declarationNode) {
            value att = declarationNode;
            return att.specifierOrInitializerExpression.expression.term;
        } else if (is Tree.MethodDefinition declarationNode) {
            value meth = declarationNode;
            value statements = meth.block.statements;
            if (meth.type is Tree.VoidModifier) {
                //TODO: in the case of a void method, tolerate 
                //      multiple statements , including control
                //      structures, not just expression statements
                if (!isSingleExpression(statements)) {
                    throw Exception("method body is not a single expression statement");
                }
                
                assert(is Tree.ExpressionStatement e = statements[0]);
                return e.expression.term;
            } else {
                if (!isSingleReturn(statements)) {
                    throw Exception("method body is not a single expression statement");
                }
                
                assert (is Tree.Return ret = statements[0]);
                return ret.expression.term;
            }
        } else if (is Tree.MethodDeclaration declarationNode) {
            value meth = declarationNode;
            return meth.specifierExpression.expression.term;
        } else if (is Tree.AttributeGetterDefinition declarationNode) {
            value att = declarationNode;
            value statements = att.block.statements;
            if (!isSingleReturn(statements)) {
                throw Exception("getter body is not a single expression statement");
            }
            
            assert(is Tree.Return r = att.block.statements[0]);
            return r.expression.term;
        } else if (is Tree.ClassDeclaration declarationNode) {
            value \ialias = declarationNode;
            return \ialias.classSpecifier;
        } else if (is Tree.InterfaceDeclaration declarationNode) {
            value \ialias = declarationNode;
            return \ialias.typeSpecifier;
        } else if (is Tree.TypeAliasDeclaration declarationNode) {
            value \ialias = declarationNode;
            return \ialias.typeSpecifier;
        } else {
            throw Exception("not a value, function, or type alias");
        }
    }

    Boolean isSingleExpression(JList<Tree.Statement> statements) {
        return statements.size() == 1
                && statements.get(0) is Tree.ExpressionStatement;
    }
    
    Boolean isSingleReturn(JList<Tree.Statement> statements) {
        return statements.size() == 1
                && statements.get(0) is Tree.Return;
    }

    void inlineReferences(Tree.Declaration declarationNode, 
        Tree.CompilationUnit declarationUnit, Node definition, 
        JList<CommonToken> declarationTokens, Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, TextChange tfc) {
        
        if (is Tree.AnyAttribute declarationNode,
            is Tree.Term expression = definition) {

            inlineAttributeReferences(pu, tokens, expression, declarationTokens, tfc);
        } else if (is Tree.AnyMethod method = declarationNode,
                   is Tree.Term expression = definition) {
            inlineFunctionReferences(pu, tokens, expression, method,
                declarationTokens, tfc);
        } else if (is Tree.ClassDeclaration classAlias = declarationNode,
                   is Tree.ClassSpecifier spec = definition) {
            inlineClassAliasReferences(pu, tokens, spec.invocationExpression,
                spec.type, classAlias, declarationTokens, tfc);
        } else if (is Tree.TypeAliasDeclaration|Tree.InterfaceDeclaration declarationNode,
                   is Tree.TypeSpecifier definition) {
            inlineTypeAliasReferences(pu, tokens, definition.type, 
                declarationTokens, tfc);
        }
    }

    void inlineFunctionReferences(Tree.CompilationUnit pu, JList<CommonToken> tokens,
        Tree.Term term, Tree.AnyMethod decNode, JList<CommonToken> declarationTokens,
        TextChange tfc) {
        
        object extends Visitor() {
            variable Boolean needsParens = false;
            shared actual void visit(Tree.InvocationExpression that) {
                super.visit(that);
                value primary = that.primary;
                if (is Tree.MemberOrTypeExpression primary) {
                    value mte = primary;
                    inlineDefinition(tokens, declarationTokens, term, tfc, that, mte, needsParens);
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                value dec = that.declaration;
                if (!that.directlyInvoked, inlineRef(that, dec)) {
                    value text = StringBuilder();
                    value \ifunction = decNode.declarationModel;
                    if (\ifunction.declaredVoid) {
                        text.append("void ");
                    }
                    
                    for (pl in decNode.parameterLists) {
                        text.append(nodes.text(pl, declarationTokens));
                    }
                    
                    text.append(" => ");
                    text.append(nodes.text(term, declarationTokens));
                    addEditToChange(tfc, newReplaceEdit(that.startIndex.intValue(),
                        that.distance.intValue(), text.string));
                }
            }
            
            shared actual void visit(Tree.OperatorExpression that) {
                value onp = needsParens;
                needsParens = true;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.StatementOrArgument that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.Expression that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
        }.visit(pu);
    }

    void inlineTypeAliasReferences(Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, Tree.Type term, 
        JList<CommonToken> declarationTokens, TextChange tfc) {
        
        object extends Visitor() {
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinition(tokens, declarationTokens, term, tfc, 
                    null, that, false);
            }
        }.visit(pu);
    }

    void inlineClassAliasReferences(Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, Tree.InvocationExpression term,
        Tree.Type type, Tree.ClassDeclaration decNode,
        JList<CommonToken> declarationTokens, TextChange tfc) {
        
        object extends Visitor() {
            variable Boolean needsParens = false;

            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinition(tokens, declarationTokens, type, tfc, null,
                    that, false);
            }
            
            shared actual void visit(Tree.InvocationExpression that) {
                super.visit(that);
                value primary = that.primary;
                if (is Tree.MemberOrTypeExpression primary) {
                    value mte = primary;
                    inlineDefinition(tokens, declarationTokens, term, tfc,
                        that, mte, needsParens);
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                value d = that.declaration;
                if (!that.directlyInvoked, inlineRef(that, d)) {
                    value text = StringBuilder();
                    value dec = decNode.declarationModel;
                    if (dec.declaredVoid) {
                        text.append("void ");
                    }
                    
                    value pl = decNode.parameterList;
                    text.append(nodes.text(pl, declarationTokens));
                    text.append(" => ");
                    text.append(nodes.text(term, declarationTokens));
                    addEditToChange(tfc, newReplaceEdit(that.startIndex.intValue(), 
                        that.distance.intValue(), text.string));
                }
            }
            
            shared actual void visit(Tree.OperatorExpression that) {
                value onp = needsParens;
                needsParens = true;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.StatementOrArgument that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.Expression that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
        }.visit(pu);
    }

    void inlineAttributeReferences(Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, Tree.Term term, 
        JList<CommonToken> declarationTokens, TextChange tfc) {
        
        object extends Visitor() {
            variable Boolean needsParens = false;
            
            shared actual void visit(Tree.Variable that) {
                if (that.type is Tree.SyntheticVariable,
                    exists od = that.declarationModel.originalDeclaration,
                    od == editorData.declaration,
                    editorData.delete) {
                    
                    value startIndex = that.specifierExpression.startIndex.intValue();
                    value text = that.identifier.text + " = ";
                    addEditToChange(tfc, newInsertEdit(startIndex, text));
                }
                
                super.visit(that);
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                inlineDefinition(tokens, declarationTokens, term, tfc, null, that, needsParens);
            }
            
            shared actual void visit(Tree.OperatorExpression that) {
                value onp = needsParens;
                needsParens = true;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
                value onp = needsParens;
                needsParens = true;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.StatementOrArgument that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
            
            shared actual void visit(Tree.Expression that) {
                value onp = needsParens;
                needsParens = false;
                super.visit(that);
                needsParens = onp;
            }
        }.visit(pu);
    }

    void inlineAliasDefinitionReference(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node reference, 
        StringBuilder result, Tree.Type it) {
        
        value t = it.typeModel;
        value td = t.declaration;
        if (is TypeParameter td,
            is Generic ta = editorData.declaration) {
            
            value index = ta.typeParameters.indexOf(td);
            
            if (index >= 0) {
                if (is Tree.SimpleType reference) {
                    value st = reference;
                    value tal = st.typeArgumentList;
                    value types = tal.types;
                    if (types.size() > index) {
                        value type = types.get(index);
                        result.append(nodes.text(type, tokens));
                        return;
                    }
                } else if (is Tree.StaticMemberOrTypeExpression st = reference) {
                    value tas = st.typeArguments;
                    
                    if (is Tree.TypeArgumentList tas) {
                        value tal = tas;
                        value types = tal.types;
                        if (types.size() > index) {
                            if (exists type = types[index]) {
                                result.append(nodes.text(type, tokens));
                            }
                            
                            return;
                        }
                    } else {
                        value types = tas.typeModels;
                        if (types.size() > index) {
                            if (exists type = types[index]) {
                                result.append(type.asSourceCodeString(it.unit));
                            }
                            
                            return;
                        }
                    }
                }
            }
        }
        
        result.append(nodes.text(it, declarationTokens));
    }

    void inlineDefinitionReference(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node reference,
        Tree.InvocationExpression? ie, StringBuilder result, 
        Tree.StaticMemberOrTypeExpression it) {
        
        value dec = it.declaration;
        if (dec.parameter,
            exists ie,
            it is Tree.BaseMemberOrTypeExpression,
            is FunctionOrValue fov = dec) {

            value param = fov.initializerParameter;
            if (param.declaration.equals(editorData.declaration)) {
                value sequenced = param.sequenced;
                if (ie.positionalArgumentList exists) {
                    interpolatePositionalArguments(result, ie, it, sequenced, tokens);
                }
                
                if (ie.namedArgumentList exists) {
                    interpolateNamedArguments(result, ie, it, sequenced, tokens);
                }
                
                return; //NOTE: early exit!
            }
        }
        
        value expressionText = nodes.text(it, declarationTokens);
        if (is Tree.QualifiedMemberOrTypeExpression reference) {
            //TODO: handle more depth, for example, foo.bar.baz
            value qmtre = reference;
            value prim = nodes.text(qmtre.primary, tokens);
            if (is Tree.QualifiedMemberOrTypeExpression it) {
                value qmte = it;
                value p = qmte.primary;
                if (is Tree.This p) {
                    value op = qmte.memberOperator.text;
                    value id = qmte.identifier.text;
                    result.append(prim).append(op).append(id);
                } else {
                    value primaryText = nodes.text(p, declarationTokens);
                    if (is Tree.MemberOrTypeExpression p) {
                        value mte = p;
                        if (mte.declaration.classOrInterfaceMember) {
                            result.append(prim).append(".").append(primaryText);
                        }
                    } else {
                        result.append(primaryText);
                    }
                }
            } else {
                if (it.declaration.classOrInterfaceMember) {
                    result.append(prim).append(".").append(expressionText);
                } else {
                    result.append(expressionText);
                }
            }
        } else {
            result.append(expressionText);
        }
    }

    void inlineDefinition(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node definition, TextChange tfc,
        Tree.InvocationExpression? that, Node reference, Boolean needsParens) {
        
        Declaration dec;
        if (is Tree.MemberOrTypeExpression reference) {
            value mte = reference;
            dec = mte.declaration;
        } else if (is Tree.SimpleType reference) {
            value st = reference;
            dec = st.declarationModel;
        } else {
            //can't happen
            return;
        }
        
        if (inlineRef(reference, dec)) {
            //TODO: breaks for invocations like f(f(x, y),z)
            value result = StringBuilder();

            class InterpolationVisitor() extends Visitor() {
                variable Integer start = 0;
                value template = nodes.text(definition, declarationTokens);
                value templateStart = definition.startIndex.intValue();
                void text(Node it) {
                    value text = template.span(start, 
                        it.startIndex.intValue() - templateStart - 1);
                    result.append(text);
                    start = it.endIndex.intValue() - templateStart;
                }
                
                shared actual void visit(Tree.BaseMemberExpression it) {
                    super.visit(it);
                    text(it);
                    inlineDefinitionReference(tokens, declarationTokens, reference, that, result, it);
                }
                
                shared actual void visit(Tree.QualifiedMemberExpression it) {
                    super.visit(it);
                    text(it);
                    inlineDefinitionReference(tokens, declarationTokens, reference, that, result, it);
                }
                
                shared actual void visit(Tree.Type it) {
                    super.visit(it);
                    text(it);
                    inlineAliasDefinitionReference(tokens, declarationTokens, reference, result, it);
                }
                
                shared void finish() {
                    value text = template.span(start, template.size - 1);
                    result.append(text);
                }
            }
            
            value iv = InterpolationVisitor();
            definition.visit(iv);
            iv.finish();
            
            if (needsParens, 
                (definition is Tree.OperatorExpression 
                    || definition is Tree.IfExpression
                    || definition is Tree.SwitchExpression
                    || definition is Tree.ObjectExpression
                    || definition is Tree.LetExpression
                    || definition is Tree.FunctionArgument)) {
                result.insert(0, "(").append(")");
            }
            
            value node = that else reference;
            
            addEditToChange(tfc, newReplaceEdit(node.startIndex.intValue(),
                node.distance.intValue(), result.string));
        }
    }

    Boolean inlineRef(Node that, Declaration dec) {
        return (!editorData.justOne 
            || that.unit == editorData.node.unit
                && that.startIndex exists
                && that.startIndex == editorData.node.startIndex)
                && dec == editorData.declaration;
    }

    void interpolatePositionalArguments(StringBuilder result, 
        Tree.InvocationExpression that, Tree.StaticMemberOrTypeExpression it, 
        Boolean sequenced, JList<CommonToken> tokens) {
        
        variable Boolean first = true;
        variable Boolean found = false;
        
        if (sequenced) {
            result.append("{");
        }
        
        value args = that.positionalArgumentList.positionalArguments;
        for (arg in args) {
            value param = arg.parameter;
            value model = param.model;
            if (it.declaration.equals(model)) {
                if (param.sequenced, arg is Tree.ListedArgument) {
                    if (first) {
                        result.append(" ");
                    }
                    
                    if (!first) {
                        result.append(", ");
                    }
                    
                    first = false;
                }
                
                result.append(nodes.text(arg, tokens));
                found = true;
            }
        }
        
        if (sequenced) {
            if (!first) {
                result.append(" ");
            }
            
            result.append("}");
        }
        
        if (!found) {
            //TODO: use default value!
        }
    }

    void interpolateNamedArguments(StringBuilder result, 
        Tree.InvocationExpression that, Tree.StaticMemberOrTypeExpression it,
        Boolean sequenced, JList<CommonToken> tokens) {
        
        variable Boolean found = false;
        value args = that.namedArgumentList.namedArguments;
        
        for (arg in args) {
            value pm = arg.parameter.model;
            if (it.declaration.equals(pm)) {
                assert (is Tree.SpecifiedArgument sa = arg);
                value argTerm = sa.specifierExpression.expression.term;
                result//.append(template.substring(start,it.getStartIndex()-templateStart))
                    .append(nodes.text(argTerm, tokens));
                //start = it.getStopIndex()-templateStart+1;
                found = true;
            }
        }
        
        if (exists seqArg = that.namedArgumentList.sequencedArgument) {
            value spm = seqArg.parameter.model;
            if (it.declaration.equals(spm)) {
                result//.append(template.substring(start,it.getStartIndex()-templateStart))
                    .append("{");
                //start = it.getStopIndex()-templateStart+1;;
                
                variable Boolean first = true;
                value pargs = seqArg.positionalArguments;
                
                for (pa in pargs) {
                    if (first) {
                        result.append(" ");
                    }
                    
                    if (!first) {
                        result.append(", ");
                    }
                    
                    first = false;
                    result.append(nodes.text(pa, tokens));
                }
                
                if (!first) {
                    result.append(" ");
                }
                
                result.append("}");
                found = true;
            }
        }
        
        if (!found) {
            if (sequenced) {
                result.append("{}");
            } else {
                //TODO: use default value!
            }
        }
    }
}
