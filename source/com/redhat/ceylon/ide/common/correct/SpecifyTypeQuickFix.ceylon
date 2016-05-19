import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport,
    TypeCompletion
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
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    CommonDocument,
    ReplaceEdit
}

shared interface SpecifyTypeQuickFix<IDocument,CompletionResult,LinkedMode>
        satisfies LinkedModeSupport<LinkedMode,IDocument,CompletionResult> {
    
    shared formal IDocument getNativeDocument(CommonDocument doc);
    
    shared formal TypeCompletion<CompletionResult,IDocument> completionManager;
    
    shared DefaultRegion? specifyType(CommonDocument document, Tree.Type typeNode,
        Boolean inEditor, Tree.CompilationUnit rootNode, Type _infType) {
        
        value offset = typeNode.startIndex.intValue();
        value length = typeNode.distance.intValue();
        value unit = rootNode.unit;
        value infType = unit.denotableType(_infType);
        
        if (!inEditor) {
            if (is Tree.LocalModifier typeNode) {
                value change = platformServices.createTextChange("Specify Type", 
                                        document);
                change.initMultiEdit();
                value decs = HashSet<Declaration>();
                importProposals.importType {
                    declarations = decs;
                    type = infType;
                    rootNode = rootNode;
                };
                value il = importProposals.applyImports {
                    change = change;
                    declarations = decs;
                    rootNode = rootNode;
                    doc = document;
                };
                value typeName 
                        = infType.asSourceCodeString(unit);
                change.addEdit(ReplaceEdit {
                        start = offset;
                        length = length;
                        text = typeName;
                    });
                
                //applyChange(change);
                
                return DefaultRegion {
                    start = offset + il;
                    length = typeName.size;
                };
            }
        } else {
            value lm = newLinkedMode();
            value nativeDoc = getNativeDocument(document);
            value proposals 
                    = completionManager.getTypeProposals {
                document = nativeDoc;
                offset = offset;
                length = length;
                infType = infType;
                rootNode = rootNode;
                kind = null;
            };
            addEditableRegion {
                lm = lm;
                doc = nativeDoc;
                start = offset;
                len = length;
                exitSeqNumber = 0;
                proposals = proposals;
            };
            installLinkedMode(nativeDoc, lm, this, -1, -1);
        }
        
        return null;
    }
    
    shared void addSpecifyTypeProposal(Node node, QuickFixData data) 
            => createProposals(node, data);

    shared void createProposal(Tree.Type type, QuickFixData data) 
            => newProposal {
                desc = "Declare explicit type";
                type = type;
                rootNode = data.rootNode;
                infType = type.typeModel;
                data = data;
            };

    void createProposals(Node node, QuickFixData data) {
        Tree.Type type;
        switch (node)
        case (is Tree.Type) {
            type = node;
        }
        case (is Tree.SpecifierExpression) {
            if (is Tree.TypedDeclaration td = 
                nodes.findDeclaration(data.rootNode, node)) {
                type = td.type;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        value cu = data.rootNode;
        value result = inferType(cu, type);
        value declaredType = type.typeModel;
        
        value it = result.inferredType;
        value gt = result.generalizedType;
        if (!isTypeUnknown(declaredType)) {
            if (type is Tree.VoidModifier) {
                if (exists it, !isTypeUnknown(it)) {
                    newProposal("Declare return type", type, cu, it, data);
                }
            }
            else {
                if (exists gt, !isTypeUnknown(gt), 
                    isTypeUnknown(it) || !gt.isSubtypeOf(it),
                    !gt.isSubtypeOf(declaredType)) {
                    newProposal("Widen type to", type, cu, gt, data);
                }
                
                if (exists it, !isTypeUnknown(it)) {
                    if (!it.isSubtypeOf(declaredType)) {
                        newProposal("Change type to", type, cu, it, data);
                    } else if (!declaredType.isSubtypeOf(it)) {
                        newProposal("Narrow type to", type, cu, it, data);
                    }
                }
                
                if (type is Tree.LocalModifier) {
                    newProposal("Declare explicit type", type, cu,
                        declaredType, data);
                }
            }
            
        } else {
            if (exists it, !isTypeUnknown(it)) {
                newProposal("Declare type", type, cu, it, data);
            }
            
            if (exists gt, !isTypeUnknown(gt), 
                isTypeUnknown(it) || !gt.isSubtypeOf(it)) {
                newProposal("Declare type", type, cu, gt, data);                    
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

    shared void addTypingProposals(QuickFixData data, Tree.Declaration? decNode) {
        if (is Tree.TypedDeclaration decNode, 
            !(decNode is Tree.ObjectDefinition|Tree.Variable)) {
            value type = decNode.type;
            if (type is Tree.LocalModifier|Tree.StaticType) {
                addSpecifyTypeProposal(type, data);
            }
        } else if (is Tree.LocalModifier|Tree.StaticType node = data.node) {
            addSpecifyTypeProposal(node, data);
        }
        
        if (is Tree.MemberOrTypeExpression node = data.node) {
            specifyTypeArgumentsQuickFix.addSpecifyTypeArgumentsProposal(node, data);
        }
    }
    
    void newProposal(String desc, Tree.Type type, 
        Tree.CompilationUnit rootNode, Type infType, QuickFixData data) 
            => data.addSpecifyTypeProposal {
                description = "``desc`` '``infType.asString(data.rootNode.unit)``'";
                type = type;
                cu = rootNode;
                infType = infType;
            };    
}
