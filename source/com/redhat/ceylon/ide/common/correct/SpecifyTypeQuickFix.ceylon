import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ModelUtil {
        isTypeUnknown
    },
    Declaration
}

import java.util {
    HashSet
}

shared interface SpecifyTypeQuickFix<IFile,IDocument,InsertEdit,TextEdit,
        TextChange,Region,Project,Data,CompletionResult,LinkedMode>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,
        Region,Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
                & LinkedModeSupport<LinkedMode,IDocument,CompletionResult>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newSpecifyTypeProposal(String desc,
        Tree.Type type, Tree.CompilationUnit cu, Type infType, Data data);

    shared Region? enterLinkedMode(TextChange change, Tree.Type typeNode,
        Boolean inEditor, Tree.CompilationUnit rootNode, Type _infType) {
        
        value offset = typeNode.startIndex.intValue();
        value length = typeNode.distance.intValue();
        value document = getDocumentForChange(change);
        value infType = rootNode.unit.denotableType(_infType);
        
        if (!inEditor) {
            initMultiEditChange(change);
            value decs = HashSet<Declaration>();
            value il = importProposals.applyImports(change, decs, rootNode, document);
            value typeName = infType.asSourceCodeString(rootNode.unit);
            
            return newRegion(offset + il, typeName.size);
        } else {
            value lm = newLinkedMode();
            value proposals = completionManager.getTypeProposals(document, offset,
                length, infType, rootNode, null);
            addEditableRegion(lm, document, offset, length, 0, proposals);
            installLinkedMode(document, lm, this, -1, -1);
        }
        
        return null;
    }
    
    shared void addSpecifyTypeProposal(Tree.Type node, Data data) {
        createProposals(node, data);
    }

    shared void createProposal(Tree.Type type, Data data) {
        newSpecifyTypeProposal("Declare explicit type", type,
            data.rootNode, type.typeModel, data);
    }

    shared void createProposals(Tree.Type type, Data data) {
        value cu = data.rootNode;
        value result = inferType(cu, type);
        value declaredType = type.typeModel;
        
        if (!isTypeUnknown(declaredType)) {
            if (!isTypeUnknown(result.generalizedType)) {
                assert(exists gt = result.generalizedType);

                if (isTypeUnknown(result.inferredType)
                        || !gt.isSubtypeOf(result.inferredType),
                    !gt.isSubtypeOf(declaredType)) {

                    newSpecifyTypeProposal("Widen type to", type, cu, gt, data);
                }
            }
            
            if (!isTypeUnknown(result.inferredType)) {
                assert(exists it = result.inferredType);
                if (!it.isSubtypeOf(declaredType)) {
                    newSpecifyTypeProposal("Change type to", type, cu, it, data);
                } else if (!declaredType.isSubtypeOf(result.inferredType)) {
                    newSpecifyTypeProposal("Narrow type to", type, cu, it, data);
                }
            }
            
            if (is Tree.LocalModifier type) {
                newSpecifyTypeProposal("Declare explicit type", type, cu,
                    declaredType, data);
            }
        } else {
            if (!isTypeUnknown(result.inferredType)) {
                assert(exists it = result.inferredType);
                newSpecifyTypeProposal("Declare type", type, cu, it, data);
            }
            
            if (!isTypeUnknown(result.generalizedType)) {
                assert(exists gt = result.generalizedType);

                if (isTypeUnknown(result.inferredType)
                    || !gt.isSubtypeOf(result.inferredType)) {
                    
                    newSpecifyTypeProposal("Declare type", type, cu, gt, data);                    
                }
            
            }
        }
    }

    InferredType inferType(Tree.CompilationUnit cu, Tree.Type type) {
        value itv = object extends InferTypeVisitor(type.unit) {
            shared actual void visit(Tree.TypedDeclaration that) {
                if (that.type == type) {
                    declaration = that.declarationModel;
                    // union(that.getType().getTypeModel());
                }
                
                super.visit(that);
            }
        };
        itv.visit(cu);
        return itv.result;
    }

}
