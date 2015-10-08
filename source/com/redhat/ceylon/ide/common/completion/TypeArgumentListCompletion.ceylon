import ceylon.collection {
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.model.typechecker.model {
    Functional,
    Reference,
    Scope
}

import java.lang {
    JInteger=Integer
}

shared interface TypeArgumentListCompletions<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared void addTypeArgumentListProposal(Integer offset, IdeComponent cpc, Node node,
        Scope scope, MutableList<CompletionResult> result, IdeCompletionManager<IdeComponent,IdeArtifact,CompletionResult,Document> completionManager) {
        JInteger? startIndex2 = node.startIndex;
        value stopIndex2 = node.endIndex;
        
        if (!exists startIndex2) {
            return; // we need it
        }

        value document = cpc.document;
        value typeArgText = completionManager.getDocumentSubstring(cpc.document, startIndex2.intValue(), stopIndex2.intValue() - startIndex2.intValue());
        Tree.CompilationUnit? upToDateAndTypechecked = cpc.rootNode; // TODO .getTypecheckedRootNode();

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
                        value pref = completionManager.getDocumentSubstring(document, that.identifier.startIndex.intValue(), 
                            that.endIndex.intValue() - that.identifier.startIndex.intValue());
                        
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals(offset, pref, cpc, result, null,
                                dec, pr, scope, null, typeArgText, false);
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
                        value pref = completionManager.getDocumentSubstring(document, that.startIndex.intValue(), 
                            that.endIndex.intValue() - that.startIndex.intValue());
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals(offset, pref, cpc, result, null,
                                dec, that.typeModel, scope, null, typeArgText, false);
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(upToDateAndTypechecked);
    }
}
