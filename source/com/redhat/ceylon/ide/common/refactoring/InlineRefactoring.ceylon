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
    Referenceable
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
import com.redhat.ceylon.ide.common.platform {
    ImportProposalServicesConsumer
}

shared Boolean isInlineRefactoringAvailable(Referenceable? ref, 
    Tree.CompilationUnit rootNode, Boolean inSameProject) {
    
    if (is Declaration declaration = ref,
        inSameProject) {
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
                    || !(getDeclarationNode(rootNode, declaration) is Tree.Variable));
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

Tree.StatementOrArgument? getDeclarationNode(
    Tree.CompilationUnit declarationUnit, Declaration declaration) {
    
    value fdv = FindDeclarationNodeVisitor(declaration);
    declarationUnit.visit(fdv);
    return fdv.declarationNode;
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

    shared Boolean isReference =>
            let (node = editorData.node)
            !node is Tree.Declaration 
            && nodes.getIdentifyingNode(node) is Tree.Identifier;
    
    shared actual Boolean enabled => true;

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
        value declarationUnit 
                = if (is CeylonUnit cu = unit)
                then cu.phasedUnit?.compilationUnit
                else null;
        
        if (!exists declarationUnit) {
            return "Compilation unit not found";
        }
        
        value declarationNode 
                = getDeclarationNode {
                    declarationUnit = declarationUnit;
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

    shared actual Change build(Change change) {
        variable Tree.CompilationUnit? declarationUnit = null;
        variable JList<CommonToken>? declarationTokens = null;
        value editorTokens = editorData.tokens;
        value declaration = editorData.declaration;
        
        value unit = declaration.unit;
        if (searchInEditor()) {
            if (editorData.rootNode.unit == unit) {
                declarationUnit = editorData.rootNode;
                declarationTokens = editorTokens;
            }
        }
        
        if (!declarationUnit exists) {
            for (pu in getAllUnits()) {
                if (pu.unit == unit) {
                    declarationUnit = pu.compilationUnit;
                    declarationTokens = pu.tokens;
                    break;
                }
            }
        }
        
        if (exists declUnit = declarationUnit,
            exists declTokens = declarationTokens,
            is Tree.Declaration declarationNode 
                    = getDeclarationNode(declUnit, 
                        editorData.declaration)) {

            value term = getInlinedTerm(declarationNode);
        
            for (phasedUnit in getAllUnits()) {
                if (searchInFile(phasedUnit)
                    && affectsUnit(phasedUnit.unit)) {
                    assert (is AnyProjectPhasedUnit phasedUnit);
                    inlineInFile {
                        tfc = newFileChange(phasedUnit);
                        parentChange = change;
                        declarationNode = declarationNode;
                        declarationUnit = declUnit;
                        term = term;
                        declarationTokens = declTokens;
                        rootNode = phasedUnit.compilationUnit;
                        tokens = phasedUnit.tokens;
                    };
                }
            }

            if (searchInEditor() 
                && affectsUnit(editorData.rootNode.unit)) {
                inlineInFile {
                    tfc = newDocChange(editorData.doc);
                    parentChange = change;
                    declarationNode = declarationNode;
                    declarationUnit = declUnit;
                    term = term;
                    declarationTokens = declTokens;
                    rootNode = editorData.rootNode;
                    tokens = editorTokens;
                };
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
            rootNode = cu;
            doc = editorData.doc;
            declarationBeingDeleted 
                    = declarationNode.declarationModel;
        };
        return importedFromDeclarationPackage;
    }

    void inlineInFile(TextChange tfc, Change parentChange, 
        Tree.Declaration declarationNode, Tree.CompilationUnit declarationUnit, 
        Node term, JList<CommonToken> declarationTokens, Tree.CompilationUnit rootNode,
        JList<CommonToken> tokens) {
        
        initMultiEditChange(tfc);
        inlineReferences(declarationNode, declarationUnit, term, 
            declarationTokens, rootNode, tokens, tfc);
        value inlined = hasChildren(tfc);
        deleteDeclaration(declarationNode, declarationUnit, rootNode, tokens, tfc);
        value importsAdded = inlined && addImports(tfc, declarationNode, rootNode);
        
        deleteImports(tfc, declarationNode, rootNode, tokens, importsAdded);
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
                    if (exists d = imt.declarationModel, 
                        d == declarationNode.declarationModel) {
                        if (list.size() == 1 
                            && !importsAddedToDeclarationPackage) {
                            //delete the whole import statement
                            addEditToChange(tfc, 
                                newDeleteEdit {
                                    start = i.startIndex.intValue();
                                    length = i.distance.intValue();
                                });
                        } else {
                            //delete just the item in the import statement...
                            addEditToChange(tfc, 
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
                                addEditToChange(tfc, 
                                    newDeleteEdit {
                                        start = prev.startIndex;
                                        length = imt.startIndex.intValue() - prev.startIndex;
                                    });
                            } else if (next.type == CeylonLexer.\iCOMMA) {
                                addEditToChange(tfc, 
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
        Tree.CompilationUnit declarationUnit, Tree.CompilationUnit cu,
        JList<CommonToken> tokens, TextChange tfc) {
        
        if (editorData.delete 
            && cu.unit == declarationUnit.unit) {

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
                addEditToChange(tfc, 
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
        JList<CommonToken> declarationTokens, Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, TextChange tfc) {
        
        if (is Tree.AnyAttribute declarationNode,
            is Tree.Term expression = definition) {
            inlineAttributeReferences {
                pu = pu;
                tokens = tokens;
                term = expression;
                declarationTokens = declarationTokens;
                tfc = tfc;
            };
        } else if (is Tree.AnyMethod method = declarationNode,
                   is Tree.Term expression = definition) {
            inlineFunctionReferences {
                pu = pu;
                tokens = tokens;
                term = expression;
                decNode = method;
                declarationTokens = declarationTokens;
                tfc = tfc;
            };
        } else if (is Tree.ClassDeclaration classAlias = declarationNode,
                   is Tree.ClassSpecifier spec = definition) {
            inlineClassAliasReferences {
                pu = pu;
                tokens = tokens;
                term = spec.invocationExpression;
                type = spec.type;
                decNode = classAlias;
                declarationTokens = declarationTokens;
                tfc = tfc;
            };
        } else if (is Tree.TypeAliasDeclaration|Tree.InterfaceDeclaration declarationNode,
                   is Tree.TypeSpecifier definition) {
            inlineTypeAliasReferences {
                pu = pu;
                tokens = tokens;
                term = definition.type;
                declarationTokens = declarationTokens;
                tfc = tfc;
            };
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
                    inlineDefinition {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        definition = term;
                        tfc = tfc;
                        invocation = that;
                        reference = primary;
                        needsParens = needsParens;
                    };
                }
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                value dec = that.declaration;
                if (!that.directlyInvoked && inlineRef(that, dec)) {
                    value text = StringBuilder();
                    if (decNode.declarationModel.declaredVoid) {
                        text.append("void ");
                    }
                    
                    for (pl in decNode.parameterLists) {
                        text.append(nodes.text(pl, declarationTokens));
                    }
                    
                    text.append(" => ");
                    text.append(nodes.text(term, declarationTokens));
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
        }.visit(pu);
    }

    void inlineTypeAliasReferences(Tree.CompilationUnit pu, 
        JList<CommonToken> tokens, Tree.Type term, 
        JList<CommonToken> declarationTokens, TextChange tfc) {
        
        object extends Visitor() {
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = term;
                    tfc = tfc;
                    invocation = null;
                    reference = that;
                    needsParens = false;
                };
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
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = type;
                    tfc = tfc;
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
                        tfc = tfc;
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
                    text.append(nodes.text(decNode.parameterList, declarationTokens));
                    text.append(" => ");
                    text.append(nodes.text(term, declarationTokens));
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
                    addEditToChange(tfc, 
                        newInsertEdit {
                            position = that.specifierExpression.startIndex.intValue();
                            text = that.identifier.text + " = ";
                        });
                }
                
                super.visit(that);
            }
            
            shared actual void visit(Tree.MemberOrTypeExpression that) {
                super.visit(that);
                inlineDefinition {
                    tokens = tokens;
                    declarationTokens = declarationTokens;
                    definition = term;
                    tfc = tfc;
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
        }.visit(pu);
    }

    void inlineAliasDefinitionReference(JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, Node reference, 
        StringBuilder result, Tree.Type it) {
        
        if (exists t = it.typeModel,
            is TypeParameter td = t.declaration,
            is Generic ta = editorData.declaration) {
            
            value index = ta.typeParameters.indexOf(td);
            if (index >= 0) {
                switch (reference)
                case (is Tree.SimpleType) {
                    value tal = reference.typeArgumentList;
                    value types = tal.types;
                    if (types.size() > index) {
                        if (exists type = types[index]) {
                            result.append(nodes.text(type, tokens));
                        }
                        return;
                    }
                }
                case (is Tree.StaticMemberOrTypeExpression) {
                    value tas = reference.typeArguments;
                    if (is Tree.TypeArgumentList tas) {
                        value types = tas.types;
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
                else {}
            }
        }
        
        result.append(nodes.text(it, declarationTokens));
    }

    void inlineDefinitionReference(
        JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Node reference, 
        Tree.InvocationExpression? invocation, 
        Tree.StaticMemberOrTypeExpression localReference, 
        StringBuilder result) {
        
        if (exists invocation,
            localReference is Tree.BaseMemberOrTypeExpression,
            is FunctionOrValue dec = localReference.declaration,
            dec.parameter) {

            value param = dec.initializerParameter;
            if (param.declaration == editorData.declaration) {
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
                return; //NOTE: early exit!
            }
        }
        
        value expressionText 
                = nodes.text(localReference, declarationTokens);
        if (is Tree.QualifiedMemberOrTypeExpression reference) {
            //TODO: handle more depth, for example, foo.bar.baz
            value prim = nodes.text(reference.primary, tokens);
            if (is Tree.QualifiedMemberOrTypeExpression localReference) {
                value p = localReference.primary;
                if (is Tree.This p) {
                    value op = localReference.memberOperator.text;
                    value id = localReference.identifier.text;
                    result.append(prim).append(op).append(id);
                } else {
                    value primaryText = nodes.text(p, declarationTokens);
                    if (is Tree.MemberOrTypeExpression p) {
                        if (p.declaration.classOrInterfaceMember) {
                            result.append(prim).append(".").append(primaryText);
                        }
                    } else {
                        result.append(primaryText);
                    }
                }
            } else {
                if (localReference.declaration.classOrInterfaceMember) {
                    result.append(prim).append(".").append(expressionText);
                } else {
                    result.append(expressionText);
                }
            }
        } else {
            result.append(expressionText);
        }
    }

    void inlineDefinition(
        JList<CommonToken> tokens, 
        JList<CommonToken> declarationTokens, 
        Node definition, 
        TextChange tfc,
        Tree.InvocationExpression? invocation, 
        Node reference, 
        Boolean needsParens) {
        
        Declaration dec;
        switch (reference)
        case (is Tree.MemberOrTypeExpression) {
            dec = reference.declaration;
        }
        case (is Tree.SimpleType) {
            dec = reference.declarationModel;
        }
        else {
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
                    value text = template.measure(start, 
                        it.startIndex.intValue() - templateStart - start);
                    result.append(text);
                    start = it.endIndex.intValue() - templateStart;
                }
                
                shared actual void visit(Tree.BaseMemberExpression it) {
                    super.visit(it);
                    text(it);
                    inlineDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        invocation = invocation;
                        result = result;
                        localReference = it;
                    };
                }
                
                shared actual void visit(Tree.QualifiedMemberExpression it) {
                    super.visit(it);
                    text(it);
                    inlineDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        invocation = invocation;
                        localReference = it;
                        result = result;
                    };
                }
                
                shared actual void visit(Tree.SimpleType it) {
                    super.visit(it);
                    text(it);
                    inlineAliasDefinitionReference {
                        tokens = tokens;
                        declarationTokens = declarationTokens;
                        reference = reference;
                        result = result;
                        it = it;
                    };
                }
                
                shared void finish() {
                    value text = template[start:template.size-start];
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
            
            value node = invocation else reference;
            
            addEditToChange(tfc, 
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
                && dec == editorData.declaration;

    void interpolatePositionalArguments(StringBuilder result, 
        Tree.InvocationExpression invocation, 
        Tree.StaticMemberOrTypeExpression reference, 
        Boolean sequenced, JList<CommonToken> tokens) {
        
        variable Boolean first = true;
        variable Boolean found = false;
        
        if (sequenced) {
            result.append("{");
        }
        
        value args = invocation.positionalArgumentList.positionalArguments;
        for (arg in args) {
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
        value args = invocation.namedArgumentList.namedArguments;
        for (arg in args) {
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
