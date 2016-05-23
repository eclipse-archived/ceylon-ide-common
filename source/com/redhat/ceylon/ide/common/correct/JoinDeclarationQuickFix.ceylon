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
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit,
    InsertEdit
}

shared object joinDeclarationQuickFix {

    shared void addJoinDeclarationProposal(QuickFixData data, 
        Tree.Statement? statement) {
        if (is Tree.SpecifierStatement statement) {
            variable value _term = statement.baseMemberExpression;

            while (is Tree.ParameterizedExpression term = _term) {
                _term = term.primary;
            }
            
            if (is Tree.BaseMemberExpression term = _term,
                is FunctionOrValue dec = term.declaration) {
                
                object extends Visitor() {
                    shared actual void visit(Tree.Body that) {
                        super.visit(that);
                        if (statement in that.statements) {
                            for (st in that.statements) {
                                if (is Tree.AttributeDeclaration st) {
                                    value ad = st;
                                    if (ad.declarationModel==dec, 
                                        !ad.specifierOrInitializerExpression exists) {
                                        createJoinDeclarationProposal {
                                            data = data;
                                            statement = statement;
                                            dec = dec;
                                            that = that;
                                            i = that.statements.indexOf(st);
                                            ad = ad;
                                        };
                                        break;
                                    }
                                } else if (is Tree.MethodDeclaration st) {
                                    value ad = st;
                                    if (ad.declarationModel==dec, 
                                        !ad.specifierExpression exists) {
                                        createJoinDeclarationProposal {
                                            data = data;
                                            statement = statement;
                                            dec = dec;
                                            that = that;
                                            i = that.statements.indexOf(st);
                                            ad = ad;
                                        };
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }.visit(data.rootNode);
            }
        }
        
        if (is Tree.AttributeDeclaration|Tree.MethodDeclaration statement) {
            Tree.SpecifierOrInitializerExpression? sie;
            switch (statement)
            case (is Tree.AttributeDeclaration) {
                sie = statement.specifierOrInitializerExpression;
            }
            case (is Tree.MethodDeclaration) {
                sie = statement.specifierExpression;
            }
            
            if (!exists sie) {
                value dec = statement.declarationModel;
                object extends Visitor() {
                    shared actual void visit(Tree.Body that) {
                        super.visit(that);
                        if (statement in that.statements) {
                            for (st in that.statements) {
                                if (is Tree.SpecifierStatement st) {
                                    value spec = st;
                                    variable value _term = spec.baseMemberExpression;
                                    while (is Tree.ParameterizedExpression term = _term) {
                                        _term = term.primary;
                                    }
                                    
                                    if (is Tree.BaseMemberExpression term = _term) {
                                        if (exists sd = term.declaration, sd==dec) {
                                            createJoinDeclarationProposal {
                                                data = data;
                                                statement = spec;
                                                dec = dec;
                                                that = that;
                                                i = that.statements.indexOf(statement);
                                                ad = statement;
                                            };
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
    
    void createJoinDeclarationProposal(QuickFixData data, 
        Tree.SpecifierStatement statement,
        Declaration dec, Tree.Body that, 
        Integer i, Tree.TypedDeclaration ad) {
        
        value change 
                = platformServices.document.createTextChange {
            name = "Join Declaration";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        
        value specifierStart 
                = statement.startIndex.intValue();
        value declarationStart = ad.startIndex.intValue();
        value declarationIdStart = ad.identifier.startIndex.intValue();
        Integer declarationLength;        
        if (that.statements.size() > i+1) {
            value next = that.statements.get(i+1);
            declarationLength 
                    = next.startIndex.intValue() 
                    - declarationStart;
        }
        else {
            declarationLength = ad.distance.intValue();
        }
        
        value text = change.document.getText {
            offset = declarationStart;
            length = declarationIdStart - declarationStart;
        };
        
        change.addEdit(DeleteEdit {
            start = declarationStart;
            length = declarationLength;
        });
        change.addEdit(InsertEdit {
            start = specifierStart;
            text = text;
        });
        
        data.addQuickFix {
            description = "Join declaration of '``dec.name``' with specification";
            change = change;
            selection = DefaultRegion(specifierStart-declarationLength);
        };
    }
}
