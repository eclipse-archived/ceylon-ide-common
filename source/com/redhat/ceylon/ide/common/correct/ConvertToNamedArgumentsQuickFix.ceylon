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
    StringBuilder,
    overloaded
}

shared object convertToNamedArgumentsQuickFix {
    
    shared void addProposal(QuickFixData data, Integer currentOffset) {

        if (exists pal = findPositionalArgumentList(currentOffset, data.rootNode),
            canConvert(pal)) {
            
            value tc = platformServices.document.createTextChange {
                name = "Convert to Named Arguments";
                input = data.phasedUnit;
            };
            value start = pal.startIndex.intValue();
            value length = pal.distance.intValue();
            value result = StringBuilder();
            if (!data.document.getChar(start-1).whitespace) {
                result.append(" ");
            }

            value indent = data.document.getIndent(pal);
            value extraIndent = indent + platformServices.document.defaultIndent;
            value delimiter = data.document.defaultLineDelimiter;

            result.append("{").append(delimiter);
            variable Boolean sequencedArgs = false;
            value tokens = data.tokens;
            value args = pal.positionalArguments;
            variable value i = 0;
            for (arg in args) {
                i++;
                Parameter? param = arg.parameter;
                if (!exists param) {
                    return;
                }

                value paramName = param.name;
                if (param.sequenced) {
                    if (sequencedArgs) {
                        result.append(", ");
                    } else if (is Tree.SpreadArgument arg) {
                        //if we _only_ have a single spread
                        //argument we don't need to wrap it
                        //in a sequence, we only need to
                        //get rid of the * operator
                        result.append(extraIndent)
                            .append(paramName)
                            .append(" = ")
                            .append(nodes.text(tokens, arg.expression))
                            .append(";")
                            .append(delimiter);
                        continue;
                    } else {
                        result.append(extraIndent)
                            .append(paramName).append(" = [");
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
                        if (is Tree.FunctionArgument fa = term) {
                            String kw
                                    = fa.type is Tree.VoidModifier //TODO: search for a return statement
                                    then "void"
                                    else "function";
                            result.append(extraIndent)
                                .append(kw).append(" ")
                                .append(paramName);
                            value unit = data.rootNode.unit;
                            nodes.appendParameters(result, fa, unit, tokens);
                            if (exists block = fa.block) {
                                value blockText
                                        = nodes.text(tokens, block)
                                        .replace(delimiter+indent,
                                                 delimiter+extraIndent);
                                result.append(" ")
                                    .append(blockText)
                                    .append(delimiter);
                            }
                            else if (exists expr = fa.expression) {
                                result.append(" => ")
                                    .append(nodes.text(tokens, expr))
                                    .append(";")
                                    .append(delimiter);
                            }
                            
                            continue;
                        }
                        
                        if (i == args.size(),
                            is Tree.SequenceEnumeration se = term) {
                            //transform iterable instantiation into sequenced args
                            if (exists sa = se.sequencedArgument) {
                                result.append(extraIndent)
                                    .append(nodes.text(tokens, sa))
                                    .append(delimiter);
                            }
                            
                            continue;
                        }
                    }
                    
                    result
                        .append(extraIndent)
                        .append(paramName)
                        .append(" = ")
                        .append(nodes.text(tokens, arg))
                        .append(";")
                        .append(delimiter);
                }
            }
            
            if (sequencedArgs) {
                result.append("];").append(delimiter);
            }
            
            result.append(indent).append("}");
            tc.addEdit(ReplaceEdit {
                start = start;
                length = length;
                text = result.string;
            });
            
            data.addQuickFix {
                description = "Convert to named arguments";
                change = tc;
                selection = DefaultRegion(start + result.string.size);
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

        overloaded
        shared actual void visit(Tree.ExtendedType that) {
            //don't add proposals for extends clause
        }

        overloaded
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
