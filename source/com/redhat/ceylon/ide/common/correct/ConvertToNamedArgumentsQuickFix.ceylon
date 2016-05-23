import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter
}

import java.lang {
    Character {
        isWhitespace
    },
    StringBuilder
}

shared object convertToNamedArgumentsQuickFix {
    
    shared void addProposal(QuickFixData data, Integer currentOffset) {
        value pal = findPositionalArgumentList(currentOffset, data.rootNode);
        
        if (exists pal,
            canConvert(pal)) {
            
            value tc = platformServices.document.createTextChange {
                name = "Convert to Named Arguments";
                input = data.phasedUnit;
            };
            value start = pal.startIndex.intValue();
            value length = pal.distance.intValue();
            value result = StringBuilder();
            if (!isWhitespace(data.document.getChar(start - 1))) {
                result.append(" ");
            }
            
            result.append("{ ");
            variable Boolean sequencedArgs = false;
            value tokens = data.tokens;
            value args = pal.positionalArguments;
            variable Integer i = 0;
            for (arg in args) {
                Parameter? param = arg.parameter;
                if (!exists param) {
                    return;
                }
                
                if (param.sequenced) {
                    if (sequencedArgs) {
                        result.append(", ");
                    } else {
                        //TODO: if we _only_ have a single spread 
                        //      argument we don't need to wrap it
                        //      in a sequence, we only need to
                        //      get rid of the * operator
                        result.append(param.name).append(" = [");
                        sequencedArgs = true;
                    }
                    
                    result.append(nodes.text(tokens, arg));
                } else {
                    if (sequencedArgs) {
                        return;
                    }
                    
                    if (is Tree.ListedArgument arg,
                        exists e = arg.expression) {
                        
                        value term = e.term;
                        if (is Tree.FunctionArgument term) {
                            value fa = term;
                            if (fa.type is Tree.VoidModifier) {
                                result.append("void ");
                            } else {
                                result.append("function ");
                            }
                            
                            result.append(param.name);
                            value unit = data.rootNode.unit;
                            nodes.appendParameters(result, fa, unit, tokens);
                            if (fa.block exists) {
                                result.append(" ").append(nodes.text(tokens, fa.block)).append(" ");
                            } else {
                                result.append(" => ");
                            }
                            
                            if (exists expr = fa.expression) {
                                result.append(nodes.text(tokens, expr)).append("; ");
                            }
                            
                            continue;
                        }
                        
                        if (++i == args.size(),
                            is Tree.SequenceEnumeration se = term) {
                            if (exists sa = se.sequencedArgument) {
                                result.append(nodes.text(tokens, sa)).append(" ");
                            }
                            
                            continue;
                        }
                    }
                    
                    result.append(param.name).append(" = ")
                            .append(nodes.text(tokens, arg)).append("; ");
                }
            }
            
            if (sequencedArgs) {
                result.append("]; ");
            }
            
            result.append("}");
            tc.addEdit(ReplaceEdit(start, length, result.string));
            value offset = start + result.string.size;
            
            data.addQuickFix {
                description = "Convert to named arguments";
                change = tc;
                selection = DefaultRegion(offset, 0);
            };
        }
    }
    
    Boolean canConvert(Tree.PositionalArgumentList pal) {
        //if it is an indirect invocations, or an 
        //invocation of an overloaded Java method
        //or constructor, we can't call it using
        //named arguments!
        for (arg in pal.positionalArguments) {
            if (!exists param = arg.parameter) {
                return false;
            }
        }
        
        return true;
    }
    
    Tree.PositionalArgumentList? findPositionalArgumentList(Integer currentOffset,
        Tree.CompilationUnit cu) {
        
        value fpav = FindPositionalArgumentsVisitor(currentOffset);
        fpav.visit(cu);
        return fpav.argumentList;
    }
    
    class FindPositionalArgumentsVisitor(Integer offset) extends Visitor() {
        shared variable Tree.PositionalArgumentList? argumentList = null;

        shared actual void visit(Tree.ExtendedType that) {
            //don't add proposals for extends clause
        }
        
        shared actual void visit(Tree.PositionalArgumentList that) {
            if (exists start = that.startIndex,
                offset >= start.intValue(),
                exists stop = that.endIndex,
                offset <= stop.intValue()) {
                
                argumentList = that;
            }
            
            super.visit(that);
        }
    }
}
