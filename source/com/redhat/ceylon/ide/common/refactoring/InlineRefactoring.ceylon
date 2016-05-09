import ceylon.collection {
    ArrayList,
    HashMap
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
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
    CeylonUnit,
    SourceFile
}
import com.redhat.ceylon.ide.common.platform {
    ImportProposalServicesConsumer
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
    Generic,
    Referenceable,
    Value,
    Scope,
    ModelUtil
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

shared Boolean isInlineRefactoringAvailable(
    Referenceable? declaration, 
    Tree.CompilationUnit rootNode, 
    Boolean inSameProject) {
    
    if (is Declaration declaration,
        inSameProject) {
        switch (declaration)
        case (is FunctionOrValue) {
            return !(declaration is Setter)
                    && (declaration.typeDeclaration exists) 
                    //&& (!declaration.typeDeclaration.anonymous) 
                    && (!declaration.unit == rootNode.unit 
                    //not a Destructure
                    || !(getDeclarationNode(rootNode, declaration) 
                            is Tree.Variable));
            //TODO: && !declaration is a control structure variable 
            //TODO: && !declaration is a value with lazy init
        }
        case (is TypeAlias) {
            return true;
        }
        case (is ClassOrInterface) {
            return declaration.\ialias;
        }
        else {
            return false;
        }
    } else {
        return false;
    }
}

Tree.StatementOrArgument? getDeclarationNode(
    Tree.CompilationUnit declarationRootNode, 
    Declaration declaration) {
    value fdv = FindDeclarationNodeVisitor(declaration);
    declarationRootNode.visit(fdv);
    return fdv.declarationNode;
}

Declaration original(Declaration d) {
    if (is Value d,
        exists od = d.originalDeclaration) {
        return original(od);
    }
    return d;
}

shared interface InlineRefactoring<ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, Change>
        satisfies AbstractRefactoring<Change>
                & ImportProposalServicesConsumer<Nothing, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange>
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

    shared Boolean isReference 
            => let (node = editorData.node)
            !node is Tree.Declaration 
            && nodes.getIdentifyingNode(node) is Tree.Identifier;
    
    enabled => true;

    shared actual Integer countReferences(Tree.CompilationUnit cu) { 
        value vis = FindReferencesVisitor(editorData.declaration);
        //TODO: don't count references which are being narrowed
        //      in a Tree.Variable, since they don't get inlined
        cu.visit(vis);
        return vis.nodeSet.size();
    }

    name => "Inline";

    "Returns a single error or a sequence of warnings."
    shared String|String[] checkAvailability() {
        value declaration = editorData.declaration;
        value unit = declaration.unit;
        value declarationUnit 
                = if (is CeylonUnit unit)
                then unit.phasedUnit?.compilationUnit
                else null;
        if (!exists declarationUnit) {
            return "Compilation unit not found";
        }
        
        value declarationNode 
                = getDeclarationNode {
                    declarationRootNode = declarationUnit;
                    declaration = editorData.declaration;
                };
        if (!exists declarationNode) {
            return "Declaration not found";
        }
        
        switch (declarationNode)
        case (is Tree.AttributeDeclaration) {
            if (!declarationNode.specifierOrInitializerExpression exists) {
                return "Cannot inline forward declaration: " + declaration.name;
            }
        }
        case (is Tree.MethodDeclaration) {
            if (!declarationNode.specifierExpression exists) {
                return "Cannot inline forward declaration: " + declaration.name;
            }
        }
        case (is Tree.AttributeGetterDefinition) {
            value statements = declarationNode.block.statements;
            if (statements.size() != 1) {
                return "Getter body is not a single statement: " + declaration.name;
            }
            if (!(statements[0] is Tree.Return)) {
                return "Getter body is not a return statement: " + declaration.name;
            }
        }
        case (is Tree.MethodDefinition) {
            if (!declarationNode.type is Tree.VoidModifier) {
                value statements = declarationNode.block.statements;
                if (statements.size() != 1) {
                    return "Function body is not a single statement: " + declaration.name;
                }
                else if (!statements[0] is Tree.Return) {
                    return "Function body is not a return statement: " + declaration.name;
                }
            }
        }
        case (is Tree.ObjectDefinition) {}
        case (is Tree.ClassDeclaration|Tree.InterfaceDeclaration) {}
        case (is Tree.TypeAliasDeclaration) {}
        else {
            return "Declaration is not a value, function, or type alias: " + declaration.name;
        }
        
        value warnings = ArrayList<String>();
        
        if (is FunctionOrValue declaration) {
            if (declaration.parameter) {
                return "Declaration is a parameter: " + declaration.name;
            }
            if (declaration.native) {
                return "Declaration is native: " + declaration.name;
            }
            if (declaration.formal) {
                return "Declaration is formal: " + declaration.name;
            }
            if (declaration.default) {
                return "Declaration is default: " + declaration.name;
            }
            if (declaration.actual) {
                return "Declaration is actual: " + declaration.name;
            }
            if (declaration.variable) {
                warnings.add("Inlined value is variable");
            }
        }
        
        declarationNode.visit(object extends Visitor() {
            shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
                super.visit(that);
                if (exists dec = that.declaration,
                    if (is Scope scope = declaration)
                        then !ModelUtil.contains(scope, dec.container) 
                        else true,
                    declaration.shared && !dec.shared && !dec.parameter) {
                    warnings.add("Definition contains reference to unshared declaration: " + dec.name);
                }
            }
            shared actual void visit(Tree.Return that) {
                super.visit(that);
                if (is Tree.MethodDefinition declarationNode,
                    declarationNode.type is Tree.VoidModifier) {
                    warnings.add("Void function body contains return statement");
                }
            }
        });
        
        return warnings.sequence();
    }
    
    shared actual Boolean affectsOtherFiles {
        value declaration = editorData.declaration;
        if (editorData.delete ||
            declaration.unit != editorData.rootNode.unit) {
            if (declaration.toplevel || declaration.shared) {
                return true;
            }
            if (declaration.parameter) {
                assert (is FunctionOrValue declaration);
                assert (is Declaration container = declaration.container);
                if ((container of Declaration).toplevel || container.shared) {
                    return true;
                }
            }
        }
        return false;
    }


    void inlineInFiles(
        Tree.Declaration declarationNode, 
        Change change, 
        Tree.CompilationUnit declarationRootNode, 
        JList<CommonToken> declarationTokens, 
        Unit editorUnit) {
        
        value term = getInlinedDefinition(declarationNode);
        
        //TODO: progress reporting!
        if (affectsOtherFiles) {
            for (phasedUnit in getAllUnits()) {
                if (searchInFile(phasedUnit)
                        && affectsUnit(phasedUnit.unit)) {
                    inlineInFile {
                        textChange = newFileChange(phasedUnit);
                        parentChange = change;
                        declarationNode = declarationNode;
                        declarationRootNode = declarationRootNode;
                        definition = term;
                        declarationTokens = declarationTokens;
                        rootNode = phasedUnit.compilationUnit;
                        tokens = phasedUnit.tokens;
                    };
                }
            }
        }
        else {
            value phasedUnit = editorPhasedUnit;
            if (searchInFile(phasedUnit)
                    && affectsUnit(phasedUnit.unit)) {
                inlineInFile {
                    textChange = newFileChange(phasedUnit);
                    parentChange = change;
                    declarationNode = declarationNode;
                    declarationRootNode = declarationRootNode;
                    definition = term;
                    declarationTokens = declarationTokens;
                    rootNode = phasedUnit.compilationUnit;
                    tokens = phasedUnit.tokens;
                };
            }
        }
        
        if (searchInEditor() 
                && affectsUnit(editorUnit)) {
            inlineInFile {
                textChange = newDocChange(editorData.doc);
                parentChange = change;
                declarationNode = declarationNode;
                declarationRootNode = declarationRootNode;
                definition = term;
                declarationTokens = declarationTokens;
                rootNode = editorData.rootNode;
                tokens = editorData.tokens;
            };
        }
    }
    
    void inlineIfDeclaration(
        Tree.CompilationUnit rootNode, 
        Declaration dec, 
        Change change, 
        Unit editorUnit, 
        JList<CommonToken> tokens) {
        if (is Tree.Declaration declarationNode 
            = getDeclarationNode {
            declarationRootNode = rootNode;
            declaration = dec;
        }) {
            inlineInFiles {
                declarationNode = declarationNode;
                change = change;
                declarationRootNode = rootNode;
                declarationTokens = tokens;
                editorUnit = editorUnit;
            };
        }
    }
    
    shared actual Change build(Change change) {
        value declarationUnit = editorData.declaration.unit;
        value editorUnit = editorData.rootNode.unit;
        
        if ((!affectsOtherFiles || searchInEditor()) &&
            editorUnit == declarationUnit) {
            inlineIfDeclaration {
                rootNode = editorData.rootNode;
                dec = editorData.declaration;
                change = change;
                editorUnit = editorUnit;
                tokens = editorData.tokens;
            };
        }
        else if (is SourceFile declarationUnit, 
                declarationUnit.modifiable,
                exists phasedUnit = declarationUnit.phasedUnit) {
            inlineIfDeclaration {
                rootNode = phasedUnit.compilationUnit;
                dec = editorData.declaration;
                change = change;
                editorUnit = editorUnit;
                tokens = phasedUnit.tokens;
            };
        }
        
        return change;
    }

    Boolean affectsUnit(Unit unit) {
        return editorData.delete && unit == editorData.declaration.unit
                || !editorData.justOne  
                || unit == editorData.node.unit;
    }

    Boolean addImports(TextChange change, Tree.Declaration declarationNode,
        Tree.CompilationUnit rootNode) {
        
        value decPack = declarationNode.unit.\ipackage;
        value filePack = rootNode.unit.\ipackage;
        variable Boolean importedFromDeclarationPackage = false;

        class AddImportsVisitor(already) extends Visitor() {
            Set<Declaration> already;
            
            shared actual void visit(Tree.BaseMemberOrTypeExpression that) {
                super.visit(that);
                if (exists dec = that.declaration) {
                    importProposals.importDeclaration(already, dec, rootNode);
                    value refPack = dec.unit.\ipackage;
                    importedFromDeclarationPackage = 
                            importedFromDeclarationPackage
                            || refPack.equals(decPack)
                            && !decPack.equals(filePack); //unnecessary
                }
            }
        }
        
        value already = HashSet<Declaration>();
        value aiv = AddImportsVisitor(already);
        declarationNode.visit(aiv);
        importProposals.applyImports {
            change = change;
            declarations = already;
            rootNode = rootNode;
            doc = editorData.doc;
            declarationBeingDeleted 
                    = declarationNode.declarationModel;
        };
        return importedFromDeclarationPackage;
    }

    void inlineInFile(TextChange textChange, Change parentChange, 
        Tree.Declaration declarationNode, Tree.CompilationUnit declarationRootNode, 
        Tree.Expression|Tree.ClassSpecifier|Tree.TypeSpecifier|Tree.Block|Tree.ObjectDefinition definition, 
        JList<CommonToken> declarationTokens, Tree.CompilationUnit rootNode,
        JList<CommonToken> tokens) {
        
        initMultiEditChange(textChange);
        inlineReferences {
            declarationNode = declarationNode;
            declarationUnit = declarationRootNode;
            definition = definition;
            declarationTokens = declarationTokens;
            rootNode = rootNode;
            tokens = tokens;
            textChange = textChange;
        };
        value inlined = hasChildren(textChange);
        deleteDeclaration {
            declarationNode = declarationNode;
            declarationUnit = declarationRootNode;
            rootNode = rootNode;
            tokens = tokens;
            textChange = textChange;
        };
        value importsAdded 
                = inlined && addImports {
            change = textChange;
            declarationNode = declarationNode;
            rootNode = rootNode;
        };
        deleteImports {
            textChange = textChange;
            declarationNode = declarationNode;
            rootNode = rootNode;
            tokens = tokens;
            importsAddedToDeclarationPackage = importsAdded;
        };
        if (hasChildren(textChange)) {
            addChangeToChange(parentChange, textChange);
        }
    }

    void deleteImports(TextChange textChange, Tree.Declaration declarationNode, 
        Tree.CompilationUnit rootNode, JList<CommonToken> tokens,
        Boolean importsAddedToDeclarationPackage) {
        
        if (exists il = rootNode.importList) {
            for (i in il.imports) {
                value list = i.importMemberOrTypeList.importMemberOrTypes;
                for (imt in list) {
                    if (exists d = imt.declarationModel, 
                        d == declarationNode.declarationModel) {
                        if (list.size() == 1 
                            && !importsAddedToDeclarationPackage) {
                            //delete the whole import statement
                            addEditToChange(textChange, 
                                newDeleteEdit {
                                    start = i.startIndex.intValue();
                                    length = i.distance.intValue();
                                });
                        } else {
                            //delete just the item in the import statement...
                            addEditToChange(textChange, 
                                newDeleteEdit {
                                    start = imt.startIndex.intValue();
                                    length = imt.distance.intValue();
                                });
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
                                addEditToChange(textChange, 
                                    newDeleteEdit {
                                        start = prev.startIndex;
                                        length = imt.startIndex.intValue() - prev.startIndex;
                                    });
                            } else if (next.type == CeylonLexer.\iCOMMA) {
                                addEditToChange(textChange, 
                                    newDeleteEdit {
                                        start = imt.endIndex.intValue();
                                        length = next.stopIndex - imt.endIndex.intValue() + 1;
                                    });
                            }
                        }
                    }
                }
            }
        }
    }
    
    void deleteDeclaration(Tree.Declaration declarationNode,
        Tree.CompilationUnit declarationUnit, Tree.CompilationUnit rootNode,
        JList<CommonToken> tokens, TextChange textChange) {
        
        if (editorData.delete 
            && rootNode.unit == declarationUnit.unit) {

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
                addEditToChange(textChange, 
                    newDeleteEdit {
                        start = t.startIndex;
                        length = declarationNode.endIndex.intValue() - t.startIndex;
                    });
            }
        }
    }

    Tree.Expression|Tree.ClassSpecifier|Tree.TypeSpecifier|Tree.Block|Tree.ObjectDefinition
    getInlinedDefinition(Tree.Declaration declarationNode) {
        switch (declarationNode)
        case (is Tree.MethodDeclaration) {
            return declarationNode.specifierExpression.expression;
        }
        case (is Tree.AttributeDeclaration) {
            return declarationNode.specifierOrInitializerExpression.expression;
        }
        case (is Tree.MethodDefinition) {
            value statements = declarationNode.block.statements;
            if (declarationNode.type is Tree.VoidModifier) {
                if (statements.size() == 1, 
                    is Tree.ExpressionStatement e = statements[0]) {
                    return e.expression;
                }
                else {
                    return declarationNode.block;
                }
            }
            else {
                if (statements.size() == 1,
                    is Tree.Return r = statements[0]) {
                    return r.expression;
                }
                else {
                    "function body is not a single return statement"
                    assert (false);
                }
            }
        }
        case (is Tree.AttributeGetterDefinition) {
            value statements = declarationNode.block.statements;
            if (statements.size() == 1, 
                is Tree.Return r = statements[0]) {
                return r.expression;
            }
            else {
                "getter body is not a single return statement"
                assert (false);
            }
        }
        case (is Tree.ClassDeclaration) {
            return declarationNode.classSpecifier;
        }
        case (is Tree.ObjectDefinition) {
            return declarationNode;
        }
        case (is Tree.InterfaceDeclaration) {
            return declarationNode.typeSpecifier;
        }
        case (is Tree.TypeAliasDeclaration) {
            return declarationNode.typeSpecifier;
        } else {
            "not a value, function, or type alias"
            assert (false);
        }
    }
    
    shared void inlineObjectReferences(
        Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, 
        Tree.ObjectDefinition declarationNode, 
        JList<CommonToken> declarationTokens, 
        TextChange textChange) {
        
        object extends Visitor() {
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = declarationNode;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                    removeBraces = false;
                    inlinedScope = declarationNode.anonymousClass;
                };
            }
        }.visit(rootNode);
    }
    
    void inlineReferences(Tree.Declaration declarationNode, 
        Tree.CompilationUnit declarationUnit, 
        Tree.Expression|Tree.ClassSpecifier|Tree.TypeSpecifier|Tree.Block|Tree.ObjectDefinition definition, 
        JList<CommonToken> declarationTokens, 
        Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, TextChange textChange) {
        
        switch (declarationNode)
        case (is Tree.AnyAttribute) {
            assert (is Tree.Expression definition);
            inlineValueReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition.term;
                declarationTokens = declarationTokens;
                decNode = declarationNode;
                textChange = textChange;
            };
        }
        case (is Tree.AnyMethod) {
            assert (is Tree.Expression|Tree.Block definition);
            inlineFunctionReferences {
                rootNode = rootNode;
                tokens = tokens;
                definition = if (is Tree.Expression definition) then definition.term else definition;
                decNode = declarationNode;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        }
        case (is Tree.ClassDeclaration) {
            assert (is Tree.ClassSpecifier definition);
            inlineClassAliasReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition.invocationExpression;
                type = definition.type;
                declarationNode = declarationNode;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        } 
        case (is Tree.TypeAliasDeclaration|Tree.InterfaceDeclaration) {
            assert (is Tree.TypeSpecifier definition);
            inlineTypeAliasReferences {
                rootNode = rootNode;
                tokens = tokens;
                type = definition.type;
                declarationNode = declarationNode;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        }
        case (is Tree.ObjectDefinition) {
            inlineObjectReferences {
                rootNode = rootNode;
                tokens = tokens;
                declarationNode = declarationNode;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        }
        else {}
    }

    void inlineFunctionReferences(Tree.CompilationUnit rootNode, JList<CommonToken> tokens,
        Tree.Term|Tree.Block definition, Tree.AnyMethod decNode, JList<CommonToken> declarationTokens,
        TextChange textChange) {
        
        value defaultArgs = HashMap<Declaration,Tree.Expression>();
        for (pl in decNode.parameterLists) {
            for (p in pl.parameters) {
                switch (p) 
                case (is Tree.InitializerParameter) {
                    if (exists e = p.specifierExpression?.expression,
                        exists d = p.parameterModel?.declaration) {
                        defaultArgs.put(d, e);
                    }
                }
                case (is Tree.ValueParameterDeclaration) {
                    if (is Tree.AttributeDeclaration ad = p.typedDeclaration,
                        exists e = ad.specifierOrInitializerExpression?.expression) {
                        defaultArgs.put(ad.declarationModel, e);
                    }
                }
                //TODO: default args for function parameters
                else {}
            }
        }
        
        object extends Visitor() {
            variable Boolean needsParens = false;
            
            shared actual void visit(Tree.MethodDeclaration that) {
                if (is Tree.Block definition,
                    is Tree.LazySpecifierExpression se 
                            = that.specifierExpression,
                    is Tree.InvocationExpression ie = se.expression.term,
                    is Tree.MemberOrTypeExpression primary = ie.primary,
                    inlineRef(primary, primary.declaration)) {
                    //delete the fat arrow
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = se.startIndex.intValue();
                            length = 2;
                        });
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = ie;
                        reference = primary;
                        needsParens = false;
                        removeBraces = false;
                        defaultArgs = defaultArgs;
                        inlinedScope = decNode.declarationModel;
                    };
                    //delete the semicolon
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = that.stopIndex.intValue();
                            length = 1;
                        });
                }
                else {
                    super.visit(that);
                }
            }
            
            shared actual void visit(Tree.AttributeDeclaration that) {
                if (is Tree.Block definition,
                    is Tree.LazySpecifierExpression se 
                            = that.specifierOrInitializerExpression,
                    is Tree.InvocationExpression ie = se.expression.term,
                    is Tree.MemberOrTypeExpression primary = ie.primary,
                    inlineRef(primary, primary.declaration)) {
                    //delete the fat arrow
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = se.startIndex.intValue();
                            length = 2;
                        });
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = ie;
                        reference = primary;
                        needsParens = false;
                        removeBraces = false;
                        defaultArgs = defaultArgs;
                        inlinedScope = null;
                    };
                    //delete the semicolon
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = that.stopIndex.intValue();
                            length = 1;
                        });
                }
                else {
                    super.visit(that);
                }
            }
            
            shared actual void visit(Tree.SpecifierStatement that) {
                if (is Tree.Block definition,
                    that.refinement,
                    is Tree.LazySpecifierExpression se 
                            = that.specifierExpression,
                    is Tree.InvocationExpression ie = se.expression.term,
                    is Tree.MemberOrTypeExpression primary = ie.primary,
                    inlineRef(primary, primary.declaration)) {
                    //convert from shortcut refinement
                    addEditToChange(textChange, 
                        newInsertEdit {
                            position = that.startIndex.intValue();
                            text = "shared actual void ";
                        });
                    //delete the fat arrow
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = se.startIndex.intValue();
                            length = 2;
                        });
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = ie;
                        reference = primary;
                        needsParens = false;
                        removeBraces = false;
                        inlinedScope = decNode.declarationModel;
                        defaultArgs = defaultArgs;
                    };
                    //delete the semicolon
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = that.stopIndex.intValue();
                            length = 1;
                        });
                }
                else {
                    super.visit(that);
                }
            }
            
            shared actual void visit(Tree.ExpressionStatement that) {
                if (is Tree.Block definition,
                    is Tree.InvocationExpression ie = that.expression.term,
                    is Tree.MemberOrTypeExpression primary = ie.primary,
                    inlineRef(primary, primary.declaration)) {
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = ie;
                        reference = primary;
                        needsParens = needsParens;
                        removeBraces = true;
                        inlinedScope = decNode.declarationModel;
                        defaultArgs = defaultArgs;
                    };
                    //delete the semicolon
                    addEditToChange(textChange,
                        newDeleteEdit {
                            start = that.stopIndex.intValue();
                            length = 1;
                        });
                }
                else {
                    super.visit(that);
                }
            }
            
            shared actual void visit(Tree.InvocationExpression that) {
                if (!is Tree.Block definition,
                    is Tree.MemberOrTypeExpression primary = that.primary,
                    inlineRef(primary, primary.declaration)) {
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = that;
                        reference = primary;
                        needsParens = needsParens;
                        removeBraces = true;
                        inlinedScope = decNode.declarationModel;
                        defaultArgs = defaultArgs;
                    };
                }
                else {
                    super.visit(that);
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                if (inlineRef(that, that.declaration)) {
                    //we have a function ref to the inlined
                    //function (not an invocation)
                    
                    //create an anonymous function to wrap
                    //the inlined function
                    value text = StringBuilder();
                    if (that.directlyInvoked) {
                        text.append("(");
                    }
                    if (decNode.declarationModel.declaredVoid) {
                        text.append("void ");
                    }
                    for (pl in decNode.parameterLists) {
                        text.append(nodes.text(declarationTokens, pl));
                    }
                    text.append(" ");
                    if (!definition is Tree.Block) {
                        text.append("=> ");
                    }
                    addEditToChange(textChange,
                        newInsertEdit {
                            position = that.startIndex.intValue();
                            text = text.string;
                        });
                    //now inline the body of the function
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = definition;
                        textChange = textChange;
                        invocation = null;
                        reference = that;
                        needsParens = needsParens;
                        removeBraces = false;
                        inlinedScope = decNode.declarationModel;
                        defaultArgs = defaultArgs;
                    };
                    if (that.directlyInvoked) {
                        addEditToChange(textChange,
                            newInsertEdit {
                                position = that.endIndex.intValue();
                                text = ")";
                            });
                    }
                }
                else {
                    value onp = needsParens;
                    if (that is Tree.QualifiedMemberOrTypeExpression) {
                        needsParens = true;
                    }
                    super.visit(that);
                    needsParens = onp;
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
        }.visit(rootNode);
    }

    void inlineTypeAliasReferences(Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, Tree.Type type, 
        Tree.TypeAliasDeclaration|Tree.InterfaceDeclaration declarationNode,
        JList<CommonToken> declarationTokens, TextChange textChange) {
        
        value defaultTypeArgs = map {
            for (tp in declarationNode.typeParameterList.typeParameterDeclarations)
            if (exists t = tp.typeSpecifier?.type)
            tp.declarationModel -> t
        };
        
        object extends Visitor() {
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinitionWithDefaultArgs {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = type;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                    removeBraces = false;
                    inlinedScope = null;
                    defaultArgs = defaultTypeArgs;
                };
            }
        }.visit(rootNode);
    }

    void inlineClassAliasReferences(Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, Tree.InvocationExpression term,
        Tree.Type type, Tree.ClassDeclaration declarationNode,
        JList<CommonToken> declarationTokens, TextChange textChange) {
        
        value defaultTypeArgs = map {
            for (tp in declarationNode.typeParameterList.typeParameterDeclarations)
            if (exists t = tp.typeSpecifier?.type)
            tp.declarationModel -> t
        };
        
        object extends Visitor() {
            variable Boolean needsParens = false;

            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinitionWithDefaultArgs {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = type;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                    removeBraces = false;
                    inlinedScope = null;
                    defaultArgs = defaultTypeArgs;
                };
            }
            
            shared actual void visit(Tree.InvocationExpression that) {
                super.visit(that);
                value primary = that.primary;
                if (is Tree.MemberOrTypeExpression primary) {
                    value mte = primary;
                    inlineDefinitionWithDefaultArgs {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = term;
                        textChange = textChange;
                        invocation = that;
                        reference = mte;
                        needsParens = needsParens;
                        removeBraces = false;
                        inlinedScope = null;
                        defaultArgs = defaultTypeArgs;
                    };
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                value d = that.declaration;
                if (!that.directlyInvoked, inlineRef(that, d)) {
                    value text = StringBuilder();
                    if (declarationNode.declarationModel.declaredVoid) {
                        text.append("void ");
                    }
                    text.append(nodes.text(declarationTokens, declarationNode.parameterList))
                        .append(" => ")
                        .append(nodes.text(declarationTokens, term));
                    addEditToChange(textChange, 
                        newReplaceEdit {
                            start = that.startIndex.intValue();
                            length = that.distance.intValue();
                            text = text.string;
                        });
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
        }.visit(rootNode);
    }

    void inlineValueReferences(Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, Tree.Term term, 
        JList<CommonToken> declarationTokens,
        Tree.AnyAttribute decNode, 
        TextChange textChange) {
        
        object extends Visitor() {
            variable value needsParens = false;
            variable value disabled = false;
            
            shared actual void visit(Tree.Variable that) {
                value dec = that.declarationModel;
                if (that.type is Tree.SyntheticVariable,
                    exists id = that.identifier,
                    original(dec) == editorData.declaration,
                    editorData.delete) {
                    disabled = true;
                    addEditToChange(textChange, 
                        newInsertEdit {
                            position = id.startIndex.intValue();
                            text = id.text + " = ";
                        });
                }
                super.visit(that);
            }
            
            shared actual void visit(Tree.Body that) {
                if (!disabled) {
                    super.visit(that);
                }
                disabled = false;
            }
            
            shared actual void visit(Tree.ElseClause that) {
                //don't re-visit the Variable!
                if (exists block = that.block) { 
                    block.visit(this);
                }
                if (exists expression = that.expression) { 
                    expression.visit(this);
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                value onp = needsParens;
                if (that is Tree.QualifiedMemberOrTypeExpression) {
                    needsParens = true;
                }
                super.visit(that);
                needsParens = onp;
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = term;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = needsParens;
                    removeBraces = false;
                    inlinedScope = 
                            if (is Tree.AttributeGetterDefinition decNode) 
                            then decNode.declarationModel else null;
                };
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
        }.visit(rootNode);
    }

    void inlineAliasDefinitionReference(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node reference, 
        StringBuilder result, Tree.BaseType baseType,
        Map<Declaration,Tree.Expression|Tree.Type> defaultArgs) {
        
        if (exists t = baseType.typeModel,
            is TypeParameter td = t.declaration,
            is Generic ta = editorData.declaration) {
            
            value index = ta.typeParameters.indexOf(td);
            if (index >= 0) {
                switch (reference)
                case (is Tree.SimpleType) {
                    if (exists type 
                            = reference.typeArgumentList.types[index] 
                            else defaultArgs[td]) {
                        result.append(nodes.text(tokens, type));
                        return; //EARLY EXIT!
                    }
                }
                case (is Tree.StaticMemberOrTypeExpression) {
                    value tas = reference.typeArguments;
                    if (is Tree.TypeArgumentList tas) {
                        if (exists type 
                                = tas.types[index] 
                                else defaultArgs[td]) {
                            result.append(nodes.text(tokens, type));
                            return;  //EARLY EXIT!
                        }
                    } else {
                        if (exists type = tas.typeModels[index]) {
                            result.append(type.asSourceCodeString(baseType.unit));
                            return; //EARLY EXIT!
                        }
                    }
                }
                else {}
            }
        }
        
        result.append(baseType.identifier.text);
    }

    void inlineDefinitionReference(
        JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Node reference, 
        Tree.InvocationExpression? invocation, 
        Tree.BaseMemberExpression|Tree.This localReference, 
        Scope? inlinedScope,
        StringBuilder result, 
        Map<Declaration,Tree.Expression|Tree.Type> defaultArgs) {
        
        if (is Tree.This localReference) {
            if (is Tree.QualifiedMemberOrTypeExpression reference,
                exists refdec = localReference.declarationModel,
                !ModelUtil.contains(inlinedScope, refdec)) {
                result.append(nodes.text(tokens, reference.primary));
            }
            else {
                result.append(nodes.text(declarationTokens, localReference));
            }
        }
        else if (exists invocation,
            is FunctionOrValue dec = localReference.declaration,
            dec.parameter, 
            exists param = dec.initializerParameter, 
            param.declaration == editorData.declaration) {
            if (exists pal = invocation.positionalArgumentList) {
                interpolatePositionalArguments {
                    result = result;
                    positionalArgumentList = pal;
                    reference = localReference;
                    sequenced = param.sequenced;
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    defaultArgs = defaultArgs;
                };
            }
            if (exists nal = invocation.namedArgumentList) {
                interpolateNamedArguments {
                    result = result;
                    namedArgumentList = nal;
                    reference = localReference;
                    sequenced = param.sequenced;
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    defaultArgs = defaultArgs;
                };
            }
        }
        else if (is Tree.QualifiedMemberOrTypeExpression reference,
            exists refDec = localReference.declaration, 
            refDec.classOrInterfaceMember,
            !ModelUtil.contains(inlinedScope, refDec.container)) {
            //assume it's a reference to the immediately 
            //containing class, i.e. the receiver
            //TODO: handle refs to outer classes
            result.append(nodes.text(tokens, reference.primary))
                    .append(".")
                    .append(nodes.text(declarationTokens, localReference));
        }
        else {
            result.append(nodes.text(declarationTokens, localReference));
        }
    }
    
    //TODO: Needed due to compiler backend bug
    //      Should just use a default arg!
    void inlineDefinition(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Tree.Term|Tree.Type|Tree.Block|Tree.ObjectDefinition definition, 
        TextChange textChange, 
        Tree.InvocationExpression? invocation, 
        Tree.MemberOrTypeExpression|Tree.SimpleType reference, 
        Boolean needsParens, Boolean removeBraces, 
        Scope? inlinedScope) 
            => inlineDefinitionWithDefaultArgs {
                tokens = tokens;
                declarationTokens = declarationTokens;
                definition = definition;
                textChange = textChange;
                invocation = invocation;
                reference = reference;
                needsParens = needsParens;
                removeBraces = removeBraces;
                inlinedScope = inlinedScope;
                defaultArgs = emptyMap;
            };

    void inlineDefinitionWithDefaultArgs(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Tree.Term|Tree.Type|Tree.Block|Tree.ObjectDefinition definition, 
        TextChange textChange, 
        Tree.InvocationExpression? invocation, 
        Tree.MemberOrTypeExpression|Tree.SimpleType reference, 
        Boolean needsParens, Boolean removeBraces, 
        Scope? inlinedScope,
        Map<Declaration,Tree.Expression|Tree.Type> defaultArgs) {
        
        if (inlineRef {
            node = reference;
            declaration =
                switch (reference)
                case (is Tree.MemberOrTypeExpression)
                    reference.declaration
                case (is Tree.SimpleType)
                    reference.declarationModel;
        }) {
            //TODO: breaks for invocations like f(f(x, y),z)
            value result = StringBuilder();
            
            class InterpolationVisitor() extends Visitor() {
                variable Integer start = 0;
                String template;
                Integer templateStart;
                if (is Tree.ObjectDefinition definition) {
                    result.append("object");
                    templateStart = definition.startIndex.intValue();
                    start = definition.identifier.endIndex.intValue() - templateStart;
                    template = nodes.text(declarationTokens, definition);
                }
                else if (removeBraces, is Tree.Block definition) {
                    value sts = definition.statements;
                    if (sts.empty) {
                        template = "";
                        templateStart = definition.startIndex.intValue()+1;
                    }
                    else {
                        value firstStatement = sts.get(0);
                        value lastStatement = sts.get(sts.size()-1);
                        template = nodes.text(declarationTokens, firstStatement, lastStatement);
                        templateStart = sts.get(0).startIndex.intValue();
                    }
                }
                else {
                    template = nodes.text(declarationTokens, definition);
                    templateStart = definition.startIndex.intValue();
                }
                
                void appendUpTo(Node it) {
                    value len = it.startIndex.intValue() - templateStart - start;
                    if (len>=0) {
                        value text = template[start:len];
                        result.append(text);
                        start = it.endIndex.intValue() - templateStart;
                    }
                }
                
                shared actual void visit(Tree.IsCase it) {
                    if (exists t = it.type) {
                        t.visit(this);
                    }
                }
                
                shared actual void visit(Tree.QualifiedMemberOrTypeExpression it) {
                    //visit the primary first!
                    if (exists p = it.primary) {
                        p.visit(this);
                    }
                }
                
                shared actual void visit(Tree.This it) {
                    appendUpTo(it);
                    inlineDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        invocation = invocation;
                        result = result;
                        localReference = it;
                        inlinedScope = inlinedScope;
                        defaultArgs = defaultArgs;
                    };
                    super.visit(it);
                }
                
                shared actual void visit(Tree.AnnotationList it) {}
                
                shared actual void visit(Tree.SpecifierStatement it) {
                    if (!it.refinement, 
                        exists lhs = it.baseMemberExpression) {
                        lhs.visit(this);
                    }
                    if (exists se = it.specifierExpression) {
                        se.visit(this);
                    }
                }
                
                shared actual void visit(Tree.BaseMemberExpression it) {
                    appendUpTo(it.identifier);
                    inlineDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        invocation = invocation;
                        result = result;
                        localReference = it;
                        inlinedScope = inlinedScope;
                        defaultArgs = defaultArgs;
                    };
                    super.visit(it);
                }
                
                shared actual void visit(Tree.QualifiedType it) {
                    //visit the qualifying type before 
                    //visiting the type argument list
                    if (exists ot = it.outerType) {
                        ot.visit(this);
                    }
                    if (exists tal = it.typeArgumentList) {
                        tal.visit(this);
                    }
                }
                
                shared actual void visit(Tree.BaseType it) {
                    appendUpTo(it.identifier);
                    inlineAliasDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        result = result;
                        baseType = it;
                        defaultArgs = defaultArgs;
                    };
                    super.visit(it);
                }
                
                shared void finish() {
                    value text = template[start:template.size-start];
                    result.append(text);
                }
            }
            
            value iv = InterpolationVisitor();
            definition.visit(iv);
            iv.finish();
            
            if (needsParens &&
                (definition is 
                    Tree.OperatorExpression
                  | Tree.IfExpression
                  | Tree.SwitchExpression
                  | Tree.ObjectExpression
                  | Tree.LetExpression
                  | Tree.FunctionArgument)) {
                result.insert(0, "(").append(")");
            }
            
            value node = invocation else reference;
            
            addEditToChange(textChange, 
                newReplaceEdit {
                    start = node.startIndex.intValue();
                    length = node.distance.intValue();
                    text = result.string;
                });
        }
    }

    Boolean inlineRef(Node node, Declaration? declaration) {
        if (!exists declaration) {
            return false;
        }
        return (!editorData.justOne
              || node.unit == editorData.node.unit
                 && node.startIndex exists
                 && node.startIndex == editorData.node.startIndex)
            && original(declaration) == editorData.declaration;
    }

    void interpolatePositionalArguments(StringBuilder result, 
        Tree.PositionalArgumentList positionalArgumentList, 
        Tree.StaticMemberOrTypeExpression reference, 
        Boolean sequenced, 
        JList<CommonToken> tokens,
        JList<CommonToken> declarationTokens,
        Map<Declaration,Tree.Expression|Tree.Type> defaultArgs) {
        
        variable Boolean first = true;
        variable Boolean found = false;
        
        if (sequenced) {
            result.append("{");
        }
        for (arg in positionalArgumentList.positionalArguments) {
            value param = arg.parameter;
            if (reference.declaration == param.model) {
                if (param.sequenced &&
                    arg is Tree.ListedArgument) {
                    if (first) {
                        result.append(" ");
                    }
                    
                    if (!first) {
                        result.append(", ");
                    }
                    
                    first = false;
                }
                
                result.append(nodes.text(tokens, arg));
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
            if (exists e = defaultArgs[reference.declaration]) {
                result.append(nodes.text(declarationTokens, e));
            }
        }
    }

    void interpolateNamedArguments(StringBuilder result, 
        Tree.NamedArgumentList namedArgumentList, 
        Tree.StaticMemberOrTypeExpression reference,
        Boolean sequenced, 
        JList<CommonToken> tokens,
        JList<CommonToken> declarationTokens,
        Map<Declaration,Tree.Expression|Tree.Type> defaultArgs) {
        
        variable Boolean found = false;
        for (arg in namedArgumentList.namedArguments) {
            if (reference.declaration == arg.parameter.model) {
                assert (is Tree.SpecifiedArgument sa = arg);
                value argTerm = sa.specifierExpression.expression.term;
                result//.append(template.substring(start,it.getStartIndex()-templateStart))
                    .append(nodes.text(tokens, argTerm));
                //start = it.getStopIndex()-templateStart+1;
                found = true;
            }
        }
        
        if (exists seqArg = namedArgumentList.sequencedArgument, 
            reference.declaration == seqArg.parameter.model) {
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
                result.append(nodes.text(tokens, pa));
            }
            
            if (!first) {
                result.append(" ");
            }
            
            result.append("}");
            found = true;
        }
        
        if (!found) {
            if (sequenced) {
                result.append("{}");
            } else {
                if (exists e = defaultArgs[reference.declaration]) {
                    result.append(nodes.text(declarationTokens, e));
                }
            }
        }
    }
}
