import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}

shared object convertToSpecifierQuickFix {
    
    shared void addConvertToSpecifierProposal(QuickFixData data, 
        Tree.Block? block, Boolean anonymousFunction = false) {
     
        if (exists block,
            block.statements.size() == 1) {
            
            Node? end;
            Node? start;
            switch (s = block.statements.get(0))
            case (is Tree.Return) {
                start = s.expression;
                end = start;
            }
            case (is Tree.ExpressionStatement) {
                start = s.expression;
                end = start;
            }
            case (is Tree.SpecifierStatement) {
                start = s.baseMemberExpression;
                end = s.specifierExpression;
            }
            else {
                return;
            }
            
            if (exists end, exists start) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Convert to Specifier";
                    input = data.phasedUnit;
                };
                change.initMultiEdit();
                
                value offset = block.startIndex.intValue();
                
                value expr = change.document.getText {
                    offset = start.startIndex.intValue();
                    length = end.endIndex.intValue() 
                            - start.startIndex.intValue();
                };
                
                change.addEdit(ReplaceEdit {
                    start = offset;
                    length = block.endIndex.intValue() - offset;
                    text = "=> " + expr + (anonymousFunction then "" else ";");
                });
                
                data.addQuickFix {
                    description = if (anonymousFunction) 
                        then "Convert anonymous function body to =>" 
                        else "Convert block to =>";
                    change = change;
                    selection = DefaultRegion(offset + 2, 0);
                };
            }
        }
    }
}
