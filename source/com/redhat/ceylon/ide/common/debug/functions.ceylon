import com.redhat.ceylon.ide.common.platform {
    CommonDocument
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    Visitor
}
import ceylon.collection {
    TreeMap
}
import java.util.regex {
    Pattern
}
import com.redhat.ceylon.common {
    JVMModuleUtil
}


shared <Integer->Node>? getFirstValidLocation(Tree.CompilationUnit rootNode,
    CommonDocument document, Integer requestedLine) {

    value nodes = TreeMap<Integer, Node>(uncurry(Integer.compare));
    
    object extends Visitor() {
        void check(Node node) {
            if (exists startIndex = node.startIndex?.intValue(),
                exists stopIndex = node.endIndex?.intValue()) {

                value adjustedStopIndex = stopIndex + 1;
                value nodeStartLine = document.getLineOfOffset(startIndex);

                if (nodeStartLine >= requestedLine) {
                    nodes[nodeStartLine] = node;
                } else {
                    value nodeEndLine = document.getLineOfOffset(adjustedStopIndex);
                    if (nodeEndLine >= requestedLine) {
                        nodes[requestedLine] = node;
                    }
                }
            }
        }
        
        shared actual void visit(Tree.Annotation that) {
        }
        
        shared actual void visit(Tree.ExecutableStatement that) {
            check(that);
            super.visit(that);
        }
        
        shared actual void visit(Tree.SpecifierOrInitializerExpression that) {
            check(that);
            super.visit(that);
        }
        
        shared actual void visit(Tree.Expression that) {
            check(that);
            super.visit(that);
        }
    }.visit(rootNode);
    
    return nodes.first;
}

"Matches local variable names like `i$20`."
shared Pattern localVariablePattern = Pattern.compile("([^$]+)\\$[0-9]+");

"Transforms a variable name from its bytecode form to its original Ceylon source form."
shared String fixVariableName(variable String name, Boolean isLocalVariable, Boolean isSynthetic) {
    if (isSynthetic, name.startsWith("val$")) {
        name = name.removeInitial("val$");
    }
    if (exists c = name.first,
        c == '$') {
        if (JVMModuleUtil.isJavaKeyword(name, 1, name.size)) {
            name = name.substring(1);
        }
    }

    if (isLocalVariable || isSynthetic,
        name.contains("$")) {

        if (name.endsWith("$param$")) {
            return name.substring(0, name.size - "$param$".size);
        }
        value matcher = localVariablePattern.matcher(name);
        if (matcher.matches()) {
            name = matcher.group(1);
        }
    }
    return name;
}
