
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}
import org.eclipse.ceylon.model.typechecker.model {
    Parameter,
    ParameterList
}

shared object convertToPositionalArgumentsQuickFix {

    shared void addProposal(QuickFixData data, Integer currentOffset) {
        value nal = findNamedArgumentList(currentOffset, data.rootNode);
        if (!exists nal) {
            return;
        }
        
        value tc = platformServices.document.createTextChange {
            name = "Convert to Positional Arguments";
            input = data.phasedUnit;
        };
        variable Integer start = nal.startIndex.intValue();
        if (data.document.getChar(start - 1) == ' ') {
            start--;
        }
        
        value length = nal.endIndex.intValue() - start;
        value result = StringBuilder().append("(");
        value tokens = data.tokens;
        value args = nal.namedArguments;
        Tree.SequencedArgument? sa = nal.sequencedArgument;
        ParameterList? parameterList = nal.namedArgumentList.parameterList;
        if (!exists parameterList) {
            return;
        }
        
        for (p in parameterList.parameters) {
            variable Boolean found = false;
            if (exists sa) {
                Parameter? param = sa.parameter;
                if (!exists param) {
                    return;
                }
                
                if (param.model == p.model) {
                    found = true;
                    result.append("{ ").append(nodes.text(tokens, sa)).append(" }");
                }
            }
            
            for (na in args) {
                Parameter? param = na.parameter;
                if (!exists param) {
                    return;
                }
                
                if (param.model == p.model) {
                    found = true;
                    switch (na)
                    case (is Tree.SpecifiedArgument) {
                        if (exists ex = na.specifierExpression?.expression?.term) {
                            if (p.sequenced) {
                                if (is Tree.Tuple ex) {
                                    result.append(nodes.text(tokens, ex.sequencedArgument));
                                }
                                else {
                                    result.append("*").append(nodes.text(tokens, ex));
                                }
                            }
                            else {
                                result.append(nodes.text(tokens, ex));
                            }
                        }
                        
                        break;
                    }
                    case (is Tree.MethodArgument) {
                        if (na.declarationModel.declaredVoid) {
                            result.append("void ");
                        }
                        
                        for (pl in na.parameterLists) {
                            result.append(nodes.text(tokens, pl));
                        }
                        
                        if (exists block = na.block) {
                            value indent = data.document.getIndent(block);
                            value defaultIndent = platformServices.document.defaultIndent;
                            value lessIndent = indent.removeTerminal(defaultIndent);
                            value blockText
                                    = nodes.text(tokens, block)
                                    .replace(indent, lessIndent);
                            result.append(" ").append(blockText);
                        }
                        
                        if (exists se = na.specifierExpression) {
                            result.append(" ").append(nodes.text(tokens, se));
                        }
                    } else {
                        return;
                    }
                }
            }
            
            if (found) {
                result.append(", ");
            }
        }
        
        if (result.size > 1) {
            result.deleteTerminal(2);
        }
        
        result.append(")");
        tc.addEdit(ReplaceEdit(start, length, result.string));
        
        value offset = start + result.string.size;
        data.addQuickFix {
            description = "Convert to positional arguments";
            change = tc;
            selection = DefaultRegion(offset);
        };
    }
    
    Tree.NamedArgumentList? findNamedArgumentList(Integer currentOffset, Tree.CompilationUnit cu) {
        value fpav = FindNamedArgumentsVisitor(currentOffset);
        fpav.visit(cu);
        return fpav.argumentList;
    }
    
    class FindNamedArgumentsVisitor(Integer offset) extends Visitor() {
        shared variable Tree.NamedArgumentList? argumentList = null;

        shared actual void visit(Tree.NamedArgumentList that) {
            if (offset >= that.startIndex.intValue(),
                offset <= that.endIndex.intValue()) {
                
                argumentList = that;
            }
            
            super.visit(that);
        }
    }
}
