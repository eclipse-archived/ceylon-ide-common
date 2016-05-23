import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.model.typechecker.model {
    FunctionOrValue
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared object addSpreadToVariadicParameterQuickFix {
    
    shared void addSpreadToSequenceParameterProposal(QuickFixData data) {
        if (is Tree.Term term = data.node) {
            value type = term.typeModel;
            value id = type.declaration.unit.iterableDeclaration;
            if (!type.getSupertype(id) exists) {
                return;
            }
            
            value fiv = FindInvocationVisitor(term);
            fiv.visit(data.rootNode);
            if (exists param = fiv.parameter,
                param.parameter,
                is FunctionOrValue param,
                param.initializerParameter.sequenced) {

                value change 
                        = platformServices.document.createTextChange {
                    name = "Spread Argument of Variadic Parameter";
                    input = data.phasedUnit;
                };
                change.addEdit(InsertEdit {
                    start = term.startIndex.intValue();
                    text = "*";
                });
                
                data.addQuickFix {
                    description = "Spread iterable argument of variadic "
                            + "parameter '``param.getName(term.unit)``'";
                    change = change;
                    selection = DefaultRegion(term.endIndex.intValue() + 3, 0);
                };
            }
        }
    }
}
