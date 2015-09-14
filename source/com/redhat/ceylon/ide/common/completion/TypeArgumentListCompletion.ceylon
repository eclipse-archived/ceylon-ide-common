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
        value stopIndex2 = node.stopIndex;
        
        if (!exists startIndex2) {
            return; // we need it
        }
        assert(exists startIndex2);

        value document = cpc.document;
        value typeArgText = completionManager.getDocumentSubstring(cpc.document, startIndex2.intValue(), stopIndex2.intValue() - startIndex2.intValue() + 1);

        object extends Visitor() {
            
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                Tree.TypeArguments? tal = that.typeArguments;
                value startIndex = if (!exists tal) then null else that.typeArguments.startIndex;

                if (exists startIndex, startIndex.intValue() == startIndex2.intValue()) {
                    Reference? pr = that.target;
                    value d = that.declaration;
                    if (d is Functional, exists pr) {
                        value pref = completionManager.getDocumentSubstring(document, that.identifier.startIndex.intValue(), 
                            that.stopIndex.intValue() - that.identifier.startIndex.intValue() + 1);
                        
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals(offset, pref, cpc, result, dec, pr, scope, null, typeArgText, false);
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
                            that.stopIndex.intValue() - that.startIndex.intValue() + 1);
                        for (dec in overloads(d)) {
                            completionManager.addInvocationProposals(offset, pref, cpc, result, dec, that.typeModel, scope, null, typeArgText, false);
                        }
                    }
                }
                super.visit(that);
            }
        }.visit(cpc.rootNode);
    }
}
