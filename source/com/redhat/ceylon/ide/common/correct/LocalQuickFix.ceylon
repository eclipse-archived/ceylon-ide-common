import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    TextChange,
    LinkedMode
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration,
    Unit
}

shared interface LocalQuickFix<in Data>
        given Data satisfies QuickFixData {

    shared formal void newProposal(Data data, String desc);

    shared formal String desc;
    shared default Boolean isEnabled(Type? type) => true;

    shared void addProposal(Data data, 
            Integer currentOffset = data.problemOffset) {
        if (enabled(data, currentOffset)) {
            newProposal(data, desc);
        }
    }
    
    shared Boolean enabled(Data data, Integer currentOffset) {
        value node = data.node;
        
        switch (st = nodes.findStatement(data.rootNode, node))
        case (is Tree.ExpressionStatement) {
            value e = st.expression;
            variable Type? resultType = e.typeModel;
            if (is Tree.InvocationExpression term = e.term) {
                value primary = term.primary;
                if (is Tree.QualifiedMemberExpression primary) {
                    value prim = primary;
                    if (!prim.memberOperator.token exists) {
                        value p = prim.primary;
                        resultType = p.typeModel;
                    }
                }
            }
            
            return isEnabled(resultType);
        }
        case (is Tree.Declaration) {
            value unit = node.unit;
            Tree.Identifier? id = st.identifier;
            if (!exists id) {
                return false;
            }
            
            value line = id.token.line;
            Declaration? d = st.declarationModel;
            if (!exists d) {
                return false;
            }
            if (d.toplevel) {
                return false;
            }
            
            value al = st.annotationList;
            value annotations = al.annotations;
            Type? resultType;
            if (exists aa = al.anonymousAnnotation,
                currentOffset <= aa.endIndex.intValue()) {
                
                if (aa.endToken.line == line) {
                    return false;
                }
                
                resultType = unit.stringType;
            }
            else if (!annotations.empty,
                currentOffset <= al.endIndex.intValue()) {
                
                value a = annotations.get(0);
                if (a.endToken.line == line) {
                    return false;
                }
                
                resultType = a.typeModel;
            }
            else if (is Tree.TypedDeclaration st, 
                    !(st is Tree.ObjectDefinition)) {
                if (exists type = st.type,
                    exists startIndex = type.startIndex?.intValue(),
                    currentOffset >= startIndex,
                    exists endIndex = type.endIndex?.intValue(),
                    currentOffset <= endIndex,
                    type.endToken.line != line) {
                    
                    switch (type)
                    case (is Tree.SimpleType) {
                        resultType = type.typeModel;
                    }
                    case (is Tree.FunctionType) {
                        resultType = unit.getCallableReturnType(type.typeModel);
                    }
                    else {
                        return false;
                    }
                }
                else {
                    return false;
                }
            }
            else {
                return false;
            }
            
            return isEnabled(resultType);
        }
        else {
            return false;
        }
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
        
        value unit = data.node.unit;
        
        variable Tree.Term|Tree.Type? expression;
        variable Node expanse;
        variable Type resultType;
        switch (st = nodes.findStatement(data.rootNode, data.node))
        case (is Tree.ExpressionStatement) {
            value e = st.expression;
            expression = e.term;
            expanse = st;
            resultType = e.typeModel;
            if (is Tree.InvocationExpression term = expression) {
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
                        expanse = term;
                        resultType = p.typeModel;
                    }
                }
            }
        }
        case (is Tree.Declaration) {
            Declaration? d = st.declarationModel;
            if (!exists d) {
                return null;
            }
            if (d.toplevel) {
                return null;
            }
            
            //some expressions get interpreted as annotations
            value annotations = st.annotationList.annotations;
            if (exists aa = st.annotationList.anonymousAnnotation,
                currentOffset <= aa.endIndex.intValue()) {
                
                expression = aa.stringLiteral;
                expanse = aa;
                resultType = unit.stringType;
            }
            else if (!annotations.empty,
                currentOffset <= st.annotationList.endIndex.intValue()) {
                
                value a = annotations.get(0);
                expression = a;
                expanse = a;
                resultType = a.typeModel;
            }
            else if (is Tree.TypedDeclaration st) {
                //some expressions look like a type declaration
                //when they appear right in front of an annotation
                //or function invocations
                value type = st.type;
                value t = type.typeModel;
                switch (type)
                case (is Tree.SimpleType) {
                    expression = type;
                    expanse = type;
                    resultType = t;
                }
                case (is Tree.FunctionType) {
                    expression = type;
                    expanse = type;
                    resultType = unit.getCallableReturnType(t);
                }
                else {
                    return null;
                }
            }
            else {
                return null;
            }
        }
        else {
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