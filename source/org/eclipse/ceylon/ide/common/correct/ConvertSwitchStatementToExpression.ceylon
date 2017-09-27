import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.model.typechecker.model {
    TypedDeclaration
}

shared object convertSwitchStatementToExpressionQuickFix {
    
    shared void addConvertSwitchStatementToExpressionProposal(QuickFixData data, 
        Tree.Statement? statement) {
        
        if (is Tree.SwitchStatement statement) {
            
            value cases = { *statement.switchCaseList.caseClauses };
            if (cases.empty) {
                return;
            }
            value caseStatementLists 
                    = cases.map((cc)=>cc.block.statements);
            value elseStatementList
                    = statement.switchCaseList.elseClause?.block?.statements;
            if (!caseStatementLists.every((statements) => statements.size()==1)) {
                return;
            }
            if (exists elseStatementList, !elseStatementList.size()==1) {
                return;
            }
            value caseStatements 
                    = caseStatementLists.map((statements) => statements.get(0));
            value elseStatement 
                    = if (exists elseStatementList) then elseStatementList[0] else null;
            value returns 
                    = caseStatements.every((statement) => statement is Tree.Return)
                    && elseStatement is Tree.Return;
            value specifications
                    = caseStatements.every((statement) => statement is Tree.SpecifierStatement)
                    && elseStatement is Tree.SpecifierStatement;
            
            value document = data.document;
            Integer start;
            Integer length;
            value builder = StringBuilder();
            TypedDeclaration? declaration;
            if (returns) {
                start = statement.startIndex.intValue();
                length = statement.distance.intValue();
                builder.append("return ");
                declaration = null;
            }
            else if (specifications) {
                assert (is Tree.SpecifierStatement first = caseStatements.first);
                declaration = first.declaration;
                if (!exists declaration) {
                    return;
                }
                if (!caseStatements.every((statement) {
                    assert (is Tree.SpecifierStatement statement);
                    return if (exists dec = statement.declaration) 
                        then dec == declaration 
                        else false;
                })) {
                    return;
                }
                if (exists elseStatement) {
                    assert (is Tree.SpecifierStatement elseStatement);
                    if (exists dec = elseStatement.declaration, 
                        dec == declaration) {
                        //ok
                    }
                    else {
                        return;
                    }
                }
                if (is Tree.AttributeDeclaration prev 
                        = findPreviousStatement(data, statement),
                    prev.declarationModel==declaration) {
                    start = prev.stopIndex.intValue();
                    length = statement.endIndex.intValue() - start;
                    builder.append(" = ");
                }
                else {
                    start = statement.startIndex.intValue();
                    length = statement.distance.intValue();
                    String specifiedText = document.getNodeText(first.baseMemberExpression);
                    builder.append(specifiedText).append(" = ");
                }
            }
            else {
                return;
            }
            
            String switchText = document.getNodeText(statement.switchClause);
            builder.append(switchText);
            
            value expressions = caseStatements.map((statement) 
                => switch (statement) 
                case (is Tree.Return) 
                    statement.expression
                case (is Tree.SpecifierStatement) 
                    statement.specifierExpression?.expression 
                else null);
            if (expressions.any((expr) => !expr exists)) {
                return;
            }
            for ([caseItem, resultExpression] 
                    in zipPairs(cases.map(Tree.CaseClause.caseItem), 
                                expressions.coalesced)) {
                String caseText = document.getNodeText(caseItem);
                String term = document.getNodeText(resultExpression);
                value resultText 
                        = if (hasLowerPrecedenceThenElse(resultExpression))
                        then "(``term``)" else term;
                builder.append(" case (").append(caseText).append(" ").append(resultText);
            }
            if (exists elseStatement) {
                value expression 
                    = switch (elseStatement) 
                    case (is Tree.Return) 
                        elseStatement.expression
                    case (is Tree.SpecifierStatement) 
                        elseStatement.specifierExpression?.expression 
                    else null;
                if (!exists expression) {
                    return;
                }
                String term = document.getNodeText(expression);
                value resultText 
                        = if (hasLowerPrecedenceThenElse(expression))
                        then "(``term``)" else term;
                builder.append(" else ").append(resultText);
            }
            builder.append(";");
            
            value change = platformServices.document.createTextChange {
                name = "Convert to Switch Statement";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                start = start;
                length = length;
                text = builder.string;
            });
            
            data.addQuickFix {
                description = "Convert to 'switch' expression";
                change = change;
                selection = DefaultRegion {
                    start = start;
                };
            };
        }
        
    }

}