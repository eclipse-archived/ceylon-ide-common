import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration,
    Unit
}
import com.redhat.ceylon.ide.common.platform {
    TextChange,
    LinkedMode,
    CommonDocument
}

shared interface LocalQuickFix<in Data>
        given Data satisfies QuickFixData {

    shared formal void newProposal(Data data, String desc);

    shared formal String desc;
    shared default Boolean isEnabled(Type type) => true;

    shared void addProposal(Data data, Integer currentOffset = data.problemOffset) {
        if (enabled(data, currentOffset)) {
            newProposal(data, desc);
        }
    }
    
    shared Boolean enabled(Data data, Integer currentOffset) {
        value rootNode = data.rootNode;
        value node = data.node;
        value st = nodes.findStatement(rootNode, node);
        
        if (is Tree.ExpressionStatement st) {
            value es = st;
            value e = es.expression;
            variable Type resultType = e.typeModel;
            value term = e.term;
            if (is Tree.InvocationExpression term) {
                value ie = term;
                value primary = ie.primary;
                if (is Tree.QualifiedMemberExpression primary) {
                    value prim = primary;
                    if (!prim.memberOperator.token exists) {
                        value p = prim.primary;
                        resultType = p.typeModel;
                    }
                }
            }
            
            return isEnabled(resultType);
        } else if (is Tree.Declaration st) {
            value unit = node.unit;
            value dec = st;
            Tree.Identifier? id = dec.identifier;
            if (!exists id) {
                return false;
            }
            
            value line = id.token.line;
            Declaration? d = dec.declarationModel;
            if (!exists d) {
                return false;
            }
            if (d.toplevel) {
                return false;
            }
            
            value annotations = dec.annotationList.annotations;
            variable Type resultType;
            if (exists aa = dec.annotationList.anonymousAnnotation,
                currentOffset <= aa.endIndex.intValue()) {
                
                if (aa.endToken.line == line) {
                    return false;
                }
                
                resultType = unit.stringType;
            } else if (!annotations.empty,
                currentOffset <= dec.annotationList.endIndex.intValue()) {
                
                value a = annotations.get(0);
                if (a.endToken.line == line) {
                    return false;
                }
                
                resultType = a.typeModel;
            } else if (is Tree.TypedDeclaration st, !(st is Tree.ObjectDefinition)) {
                value type = st.type;
                if (currentOffset <= type.endIndex.intValue(),
                    currentOffset >= type.startIndex.intValue(),
                    type.endToken.line != line) {
                    
                    resultType = type.typeModel;
                    if (is Tree.SimpleType type) {
                    } else if (is Tree.FunctionType type) {
                        resultType = unit.getCallableReturnType(resultType);
                    } else {
                        return false;
                    }
                } else {
                    return false;
                }
            } else {
                return false;
            }
            
            return isEnabled(resultType);
        }
        
        return false;
    }
}

shared interface AbstractLocalProposal {

    shared formal TextChange createChange(QuickFixData file, Node expanse, Integer endIndex);
    shared formal void addLinkedPositions(LinkedMode lm, Unit unit);

    shared formal variable {String*} names;
    shared formal variable Integer currentOffset;
    shared formal variable Integer offset;
    shared formal variable Type? type;
    shared formal variable Integer exitPos;
    
    shared String initialName => names.first else "<unknown>";

    shared TextChange? performInitialChange(QuickFixData data, Integer currentOffset) {
        value st = nodes.findStatement(data.rootNode, data.node);
        variable Node expression;
        variable Node expanse;
        variable Type resultType;
        value unit = data.node.unit;
        
        if (is Tree.ExpressionStatement es = st) {
            value e = es.expression;
            expression = e;
            expanse = es;
            resultType = e.typeModel;
            value term = e.term;
            if (is Tree.InvocationExpression term) {
                value ie = term;
                value primary = ie.primary;
                if (is Tree.QualifiedMemberExpression primary) {
                    value prim = primary;
                    if (!prim.memberOperator.token exists) {
                        //an expression followed by two annotations 
                        //can look like a named operator expression
                        //even though that is disallowed as an
                        //expression statement
                        value p = prim.primary;
                        expression = p;
                        expanse = expression;
                        resultType = p.typeModel;
                    }
                }
            }
        } else if (is Tree.Declaration st) {
            value dec = st;
            Declaration? d = dec.declarationModel;
            if (!exists d) {
                return null;
            }
            if (d.toplevel) {
                return null;
            }
            
            //some expressions get interpreted as annotations
            value annotations = dec.annotationList.annotations;
            if (exists aa = dec.annotationList.anonymousAnnotation,
                currentOffset <= aa.endIndex.intValue()) {
                
                expression = aa;
                expanse = expression;
                resultType = unit.stringType;
            } else if (!annotations.empty,
                currentOffset <= dec.annotationList.endIndex.intValue()) {
                
                value a = annotations.get(0);
                expression = a;
                expanse = expression;
                resultType = a.typeModel;
            } else if (is Tree.TypedDeclaration td = st) {
                //some expressions look like a type declaration
                //when they appear right in front of an annotation
                //or function invocations
                value type = td.type;
                value t = type.typeModel;
                if (is Tree.SimpleType type) {
                    expression = type;
                    expanse = expression;
                    resultType = t;
                } else if (is Tree.FunctionType type) {
                    expression = type;
                    expanse = expression;
                    resultType = unit.getCallableReturnType(t);
                } else {
                    return null;
                }
            } else {
                return null;
            }
        } else {
            return null;
        }
        
        value startIndex = expanse.startIndex.intValue();
        value endIndex = expanse.endIndex.intValue();
        if (currentOffset<startIndex || currentOffset>endIndex) {
            return null;
        }
        
        names = nodes.nameProposals(expression);
        offset = startIndex;
        type = unit.denotableType(resultType);
        this.currentOffset = currentOffset;
        
        return createChange(data, expanse, endIndex);
    }

}