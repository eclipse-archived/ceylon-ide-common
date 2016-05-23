import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    Functional,
    Reference,
    Scope
}

import java.lang {
    JInteger=Integer
}

shared interface TypeArgumentListCompletions {
    
    shared void addTypeArgumentListProposal(Integer offset, CompletionContext ctx, Node node,
        Scope scope) {
        JInteger? startIndex2 = node.startIndex;
        value stopIndex2 = node.endIndex;
        
        if (!exists startIndex2) {
            return; // we need it
        }

        value document = ctx.commonDocument;
        value typeArgText = document.getText {
            offset = startIndex2.intValue();
            length = stopIndex2.intValue() - startIndex2.intValue();
        };
        Tree.CompilationUnit? upToDateAndTypechecked = ctx.typecheckedRootNode;

        if (!exists upToDateAndTypechecked) {
            return;
        }
        
        object extends Visitor() {
            
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                Tree.TypeArguments? tal = that.typeArguments;
                value startIndex = if (!exists tal) then null else tal.startIndex;

                if (exists startIndex, startIndex.intValue() == startIndex2.intValue()) {
                    Reference? pr = that.target;
                    value d = that.declaration;
                    if (d is Functional, exists pr) {
                        value pref = document.getText(that.identifier.startIndex.intValue(), 
                            that.endIndex.intValue() - that.identifier.startIndex.intValue());
                        
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals {
                                offset = offset;
                                prefix = pref;
                                ctx = ctx;
                                dwp = null;
                                dec = dec;
                                pr = pr;
                                scope = scope;
                                ol = null;
                                typeArgs = typeArgText;
                                isMember = false;
                            };
                        }
                    }
                }
                super.visit(that);
            }
            
            shared actual void visit(Tree.SimpleType that) {
                Tree.TypeArgumentList? tal = that.typeArgumentList;
                value startIndex = if (!exists tal) then null else tal.startIndex;
                if (exists startIndex, startIndex.intValue() == startIndex2.intValue()) {
                    value d = that.declarationModel;
                    if (is Functional d) {
                        value pref = document.getText(that.startIndex.intValue(), 
                            that.endIndex.intValue() - that.startIndex.intValue());
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals {
                                offset = offset;
                                prefix = pref;
                                ctx = ctx;
                                dwp = null;
                                dec = dec;
                                pr = that.typeModel;
                                scope = scope;
                                ol = null;
                                typeArgs = typeArgText;
                                isMember = false;
                            };
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(upToDateAndTypechecked);
    }
}
