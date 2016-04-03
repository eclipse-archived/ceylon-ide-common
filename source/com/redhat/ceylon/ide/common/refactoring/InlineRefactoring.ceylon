import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    TypecheckerUnit
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
    ImportProposalServicesConsumer
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
    Generic,
    Referenceable,
    Value
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
            return !declaration.parameter 
                    && !(declaration is Setter) 
                    && !declaration.default 
                    && !declaration.formal 
                    && !declaration.native 
                    && (declaration.typeDeclaration exists) 
                    && (!declaration.typeDeclaration.anonymous) 
                    && (declaration.toplevel 
                        || !declaration.shared 
                        || !declaration.formal && !declaration.default && !declaration.actual)
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
    
    shared actual Boolean enabled => true;

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
        if (is Tree.AttributeDeclaration declarationNode,
            !declarationNode.specifierOrInitializerExpression exists) {

            return "Cannot inline forward declaration: " + declaration.name;
        }
        if (is Tree.MethodDeclaration declarationNode,
            !declarationNode.specifierExpression exists) {

            return "Cannot inline forward declaration: " + declaration.name;            
        }
        
        if (is Tree.AttributeGetterDefinition declarationNode) {
            value statements = declarationNode.block.statements;
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
            if (declarationNode.declarationModel.variable) {
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

    void inlineInFiles(
        Tree.Declaration declarationNode, 
        Change change, 
        Tree.CompilationUnit declarationRootNode, 
        JList<CommonToken> declarationTokens, 
        TypecheckerUnit editorUnit) {
        
        value term = getInlinedTerm(declarationNode);
        
        for (phasedUnit in getAllUnits()) {
            if (searchInFile(phasedUnit)
                && affectsUnit(phasedUnit.unit)) {
                assert (is AnyProjectPhasedUnit phasedUnit);
                inlineInFile {
                    textChange = newFileChange(phasedUnit);
                    parentChange = change;
                    declarationNode = declarationNode;
                    declarationRootNode = declarationRootNode;
                    term = term;
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
                term = term;
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
        TypecheckerUnit editorUnit, 
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
        
        if (searchInEditor() &&
            editorUnit == declarationUnit) {
            inlineIfDeclaration {
                rootNode = editorData.rootNode;
                dec = editorData.declaration;
                change = change;
                editorUnit = editorUnit;
                tokens = editorData.tokens;
            };
        }
        else {
            for (phasedUnit in getAllUnits()) {
                if (phasedUnit.unit == declarationUnit) {
                    inlineIfDeclaration {
                        rootNode = phasedUnit.compilationUnit;
                        dec = editorData.declaration;
                        change = change;
                        editorUnit = editorUnit;
                        tokens = phasedUnit.tokens;
                    };
                    break;
                }
            }
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
        Node term, JList<CommonToken> declarationTokens, Tree.CompilationUnit rootNode,
        JList<CommonToken> tokens) {
        
        initMultiEditChange(textChange);
        inlineReferences {
            declarationNode = declarationNode;
            declarationUnit = declarationRootNode;
            definition = term;
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

    Node getInlinedTerm(Tree.Declaration declarationNode) {
        switch (declarationNode)
        case (is Tree.AttributeDeclaration) {
            return declarationNode.specifierOrInitializerExpression.expression.term;
        }
        case (is Tree.MethodDefinition) {
            value statements = declarationNode.block.statements;
            if (declarationNode.type is Tree.VoidModifier) {
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
        }
        case (is Tree.MethodDeclaration) {
            return declarationNode.specifierExpression.expression.term;
        }
        case (is Tree.AttributeGetterDefinition) {
            value statements = declarationNode.block.statements;
            if (!isSingleReturn(statements)) {
                throw Exception("getter body is not a single expression statement");
            }
            
            assert(is Tree.Return r 
                = declarationNode.block.statements[0]);
            return r.expression.term;
        }
        case (is Tree.ClassDeclaration) {
            return declarationNode.classSpecifier;
        }
        case (is Tree.InterfaceDeclaration) {
            return declarationNode.typeSpecifier;
        }
        case (is Tree.TypeAliasDeclaration) {
            return declarationNode.typeSpecifier;
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
        JList<CommonToken> declarationTokens, 
        Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, TextChange textChange) {
        
        if (is Tree.AnyAttribute declarationNode,
            is Tree.Term definition) {
            inlineAttributeReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        } else if (is Tree.AnyMethod declarationNode,
                   is Tree.Term definition) {
            inlineFunctionReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition;
                decNode = declarationNode;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        } else if (is Tree.ClassDeclaration declarationNode,
                   is Tree.ClassSpecifier definition) {
            inlineClassAliasReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition.invocationExpression;
                type = definition.type;
                decNode = declarationNode;
                declarationTokens = declarationTokens;
                tfc = textChange;
            };
        } else if (is Tree.TypeAliasDeclaration|Tree.InterfaceDeclaration declarationNode,
                   is Tree.TypeSpecifier definition) {
            inlineTypeAliasReferences {
                rootNode = rootNode;
                tokens = tokens;
                term = definition.type;
                declarationTokens = declarationTokens;
                textChange = textChange;
            };
        }
    }

    void inlineFunctionReferences(Tree.CompilationUnit rootNode, JList<CommonToken> tokens,
        Tree.Term term, Tree.AnyMethod decNode, JList<CommonToken> declarationTokens,
        TextChange textChange) {
        
        object extends Visitor() {
            variable Boolean needsParens = false;
            
            shared actual void visit(Tree.InvocationExpression that) {
                super.visit(that);
                if (is Tree.MemberOrTypeExpression primary = that.primary) {
                    inlineDefinition {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = term;
                        textChange = textChange;
                        invocation = that;
                        reference = primary;
                        needsParens = needsParens;
                    };
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                if (!that.directlyInvoked && 
                    inlineRef(that, that.declaration)) {
                    //we have a function ref to the inlined
                    //function (not an invocation)
                    
                    //create an anonymous function to wrap
                    //the inlined function
                    value text = StringBuilder();
                    if (decNode.declarationModel.declaredVoid) {
                        text.append("void ");
                    }
                    for (pl in decNode.parameterLists) {
                        text.append(nodes.text(pl, declarationTokens));
                    }
                    text.append(" => ");
                    addEditToChange(textChange,
                        newInsertEdit {
                            position = that.startIndex.intValue();
                            text = text.string;
                        });
                    //now inline the body of the function
                    inlineDefinition {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = term;
                        textChange = textChange;
                        invocation = null;
                        reference = that;
                        needsParens = needsParens;
                    };
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
        JList<CommonToken> tokens, Tree.Type term, 
        JList<CommonToken> declarationTokens, TextChange textChange) {
        
        object extends Visitor() {
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = term;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                };
            }
        }.visit(rootNode);
    }

    void inlineClassAliasReferences(Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, Tree.InvocationExpression term,
        Tree.Type type, Tree.ClassDeclaration decNode,
        JList<CommonToken> declarationTokens, TextChange tfc) {
        
        object extends Visitor() {
            variable Boolean needsParens = false;

            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = type;
                    textChange = tfc;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                };
            }
            
            shared actual void visit(Tree.InvocationExpression that) {
                super.visit(that);
                value primary = that.primary;
                if (is Tree.MemberOrTypeExpression primary) {
                    value mte = primary;
                    inlineDefinition {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = term;
                        textChange = tfc;
                        invocation = that;
                        reference = mte;
                        needsParens = needsParens;
                    };
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                value d = that.declaration;
                if (!that.directlyInvoked, inlineRef(that, d)) {
                    value text = StringBuilder();
                    if (decNode.declarationModel.declaredVoid) {
                        text.append("void ");
                    }
                    text.append(nodes.text(decNode.parameterList, declarationTokens))
                        .append(" => ")
                        .append(nodes.text(term, declarationTokens));
                    addEditToChange(tfc, 
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

    void inlineAttributeReferences(Tree.CompilationUnit rootNode, 
        JList<CommonToken> tokens, Tree.Term term, 
        JList<CommonToken> declarationTokens, TextChange textChange) {
        
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
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = term;
                    textChange = textChange;
                    invocation = null;
                    reference = that;
                    needsParens = needsParens;
                };
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
        }.visit(rootNode);
    }

    void inlineAliasDefinitionReference(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node reference, 
        StringBuilder result, Tree.BaseType baseType) {
        
        if (exists t = baseType.typeModel,
            is TypeParameter td = t.declaration,
            is Generic ta = editorData.declaration) {
            
            value index = ta.typeParameters.indexOf(td);
            if (index >= 0) {
                switch (reference)
                case (is Tree.SimpleType) {
                    value types = reference.typeArgumentList.types;
                    if (types.size() > index, 
                        exists type = types[index]) {
                        result.append(nodes.text(type, tokens));
                        return; //EARLY EXIT!
                    }
                }
                case (is Tree.StaticMemberOrTypeExpression) {
                    value tas = reference.typeArguments;
                    if (is Tree.TypeArgumentList tas) {
                        value types = tas.types;
                        if (types.size() > index, 
                            exists type = types[index]) {
                            result.append(nodes.text(type, tokens));
                            return;  //EARLY EXIT!
                        }
                    } else {
                        value types = tas.typeModels;
                        if (types.size() > index, 
                            exists type = types[index]) {
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
        StringBuilder result) {
        
        if (is Tree.This localReference) {
            if (is Tree.QualifiedMemberOrTypeExpression reference) {
                result.append(nodes.text(reference.primary, tokens));
            }
            else {
                result.append(nodes.text(localReference, declarationTokens));
            }
        }
        else if (exists invocation,
            is FunctionOrValue dec = localReference.declaration,
            dec.parameter, 
            exists param = dec.initializerParameter, 
            param.declaration == editorData.declaration) {
            if (invocation.positionalArgumentList exists) {
                interpolatePositionalArguments {
                    result = result;
                    invocation = invocation;
                    reference = localReference;
                    sequenced = param.sequenced;
                    tokens = tokens;
                };
            }
            if (invocation.namedArgumentList exists) {
                interpolateNamedArguments {
                    result = result;
                    invocation = invocation;
                    reference = localReference;
                    sequenced = param.sequenced;
                    tokens = tokens;
                };
            }
        }
        else if (is Tree.QualifiedMemberOrTypeExpression reference, 
            localReference.declaration.classOrInterfaceMember) {
            //assume it's a reference to the immediately 
            //containing class, i.e. the receiver
            //TODO: handle refs to outer classes
            result.append(nodes.text(reference.primary, tokens))
                .append(".")
                .append(nodes.text(localReference, declarationTokens));
        }
        else {
            result.append(nodes.text(localReference, declarationTokens));
        }
    }

    void inlineDefinition(
        JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Node definition, 
        TextChange textChange,
        Tree.InvocationExpression? invocation, 
        Tree.MemberOrTypeExpression|Tree.SimpleType reference, 
        Boolean needsParens) {
        
        value dec = switch (reference)
            case (is Tree.MemberOrTypeExpression) 
                reference.declaration
            case (is Tree.SimpleType) 
                reference.declarationModel;
        
        if (inlineRef(reference, dec)) {
            //TODO: breaks for invocations like f(f(x, y),z)
            value result = StringBuilder();

            class InterpolationVisitor() extends Visitor() {
                variable Integer start = 0;
                value template = nodes.text(definition, declarationTokens);
                value templateStart = definition.startIndex.intValue();
                void appendUpTo(Node it) {
                    value text = template[start:
                        it.startIndex.intValue() - templateStart - start];
                    result.append(text);
                    start = it.endIndex.intValue() - templateStart;
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
                    };
                    super.visit(it);
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

    Boolean inlineRef(Node that, Declaration dec)
            => (!editorData.justOne
              || that.unit == editorData.node.unit
                 && that.startIndex exists
                 && that.startIndex == editorData.node.startIndex)
            && original(dec) == editorData.declaration;

    void interpolatePositionalArguments(StringBuilder result, 
        Tree.InvocationExpression invocation, 
        Tree.StaticMemberOrTypeExpression reference, 
        Boolean sequenced, JList<CommonToken> tokens) {
        
        variable Boolean first = true;
        variable Boolean found = false;
        
        if (sequenced) {
            result.append("{");
        }
        for (arg in invocation.positionalArgumentList.positionalArguments) {
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
        Tree.InvocationExpression invocation, 
        Tree.StaticMemberOrTypeExpression reference,
        Boolean sequenced, 
        JList<CommonToken> tokens) {
        
        variable Boolean found = false;
        for (arg in invocation.namedArgumentList.namedArguments) {
            if (reference.declaration == arg.parameter.model) {
                assert (is Tree.SpecifiedArgument sa = arg);
                value argTerm = sa.specifierExpression.expression.term;
                result//.append(template.substring(start,it.getStartIndex()-templateStart))
                    .append(nodes.text(argTerm, tokens));
                //start = it.getStopIndex()-templateStart+1;
                found = true;
            }
        }
        
        if (exists seqArg = invocation.namedArgumentList.sequencedArgument, 
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
                result.append(nodes.text(pa, tokens));
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
                //TODO: use default value!
            }
        }
    }
}
