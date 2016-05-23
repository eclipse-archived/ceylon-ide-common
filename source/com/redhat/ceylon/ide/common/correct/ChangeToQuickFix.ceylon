import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil
}

shared object changeToQuickFix {
    
    shared void changeToFunction(QuickFixData data) {
        if (is Tree.AnyMethod method 
                = nodes.findDeclarationWithBody {
                    cu = data.rootNode;
                    node = data.node;
                },
            is Tree.Return ret = data.node,
            is Tree.VoidModifier type = method.type) {
            value change 
                    = platformServices.document.createTextChange {
                name = "Change To Function";
                input = data.phasedUnit;
            };
            value unit = data.rootNode.unit;
            value rt = ret.expression.typeModel;
            change.addEdit(ReplaceEdit {
                start = type.startIndex.intValue();
                length = type.distance.intValue();
                text = ModelUtil.isTypeUnknown(rt) 
                    then "function" 
                    else rt.asSourceCodeString(unit);
            });
            
            data.addQuickFix("Make function non-'void'", change);
        }
    }

    shared void changeToVoid(QuickFixData data) {
        if (is Tree.AnyMethod dec 
                = nodes.findDeclarationWithBody {
                    cu = data.rootNode;
                    node = data.node;
                }) {
            value type = dec.type;
            if (!(type is Tree.VoidModifier)) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Change To Void";
                    input = data.phasedUnit;
                };
                change.addEdit(ReplaceEdit {
                    start = type.startIndex.intValue();
                    length = type.distance.intValue();
                    text = "void";
                });
                
                data.addQuickFix("Make function 'void'", change);
            }
        }
    }
}
