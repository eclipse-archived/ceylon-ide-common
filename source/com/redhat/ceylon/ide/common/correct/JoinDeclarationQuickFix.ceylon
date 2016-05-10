import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue,
    Declaration
}

shared interface JoinDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared void addJoinDeclarationProposal(Data data, IFile file, Tree.Statement? statement) {
        if (is Tree.SpecifierStatement spec = statement) {
            variable value _term = spec.baseMemberExpression;

            while (is Tree.ParameterizedExpression term = _term) {
                _term = term.primary;
            }
            
            if (is Tree.BaseMemberExpression term = _term,
                is FunctionOrValue dec = term.declaration) {
                
                object extends Visitor() {
                    shared actual void visit(Tree.Body that) {
                        super.visit(that);
                        if (that.statements.contains(statement)) {
                            for (st in that.statements) {
                                if (is Tree.AttributeDeclaration st) {
                                    value ad = st;
                                    if (ad.declarationModel.equals(dec), !ad.specifierOrInitializerExpression exists) {
                                        createJoinDeclarationProposal(data, spec, file, dec, that, that.statements.indexOf(st), ad);
                                        break;
                                    }
                                } else if (is Tree.MethodDeclaration st) {
                                    value ad = st;
                                    if (ad.declarationModel.equals(dec), !ad.specifierExpression exists) {
                                        createJoinDeclarationProposal(data, spec, file, dec, that, that.statements.indexOf(st), ad);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }.visit(data.rootNode);
            }
        }
        
        if (is Tree.AttributeDeclaration|Tree.MethodDeclaration ad = statement) {
            Tree.SpecifierOrInitializerExpression? sie;
            if (is Tree.AttributeDeclaration statement) {
                sie = statement.specifierOrInitializerExpression;
            } else if (is Tree.MethodDeclaration statement) {
                sie = statement.specifierExpression;
            } else {
                sie = null;
            }
            
            if (!exists sie) {
                value dec = ad.declarationModel;
                object extends Visitor() {
                    shared actual void visit(Tree.Body that) {
                        super.visit(that);
                        if (that.statements.contains(statement)) {
                            for (st in that.statements) {
                                if (is Tree.SpecifierStatement st) {
                                    value spec = st;
                                    variable value _term = spec.baseMemberExpression;
                                    while (is Tree.ParameterizedExpression term = _term) {
                                        _term = term.primary;
                                    }
                                    
                                    if (is Tree.BaseMemberExpression term = _term) {
                                        if (exists sd = (term).declaration,
                                            sd.equals(dec)) {
                                            createJoinDeclarationProposal(data, spec, file, dec, that, that.statements.indexOf(statement), ad);
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.visit(data.rootNode);
            }
        }
    }
    
    void createJoinDeclarationProposal(Data data, Tree.SpecifierStatement statement,
        IFile file, Declaration dec, Tree.Body that, 
        Integer i, Tree.TypedDeclaration ad) {
        
        value change = newTextChange("Join Declaration", file);
        initMultiEditChange(change);
        value document = getDocumentForChange(change);
        value declarationStart = ad.startIndex.intValue();
        value declarationIdStart = ad.identifier.startIndex.intValue();
        variable value declarationLength = ad.distance.intValue();
        
        if (that.statements.size() > i+1) {
            value next = that.statements.get(i + 1);
            declarationLength = next.startIndex.intValue() - declarationStart;
        }
        
        value text = getDocContent(document, declarationStart, declarationIdStart - declarationStart);
        
        addEditToChange(change, newDeleteEdit(declarationStart, declarationLength));
        value specifierStart = statement.startIndex.intValue();
        addEditToChange(change, newInsertEdit(specifierStart, text));
        
        value desc = "Join declaration of '" + dec.name + "' with specification";
        
        newProposal(data, desc, change, DefaultRegion(specifierStart - declarationLength, 0));
    }
}
