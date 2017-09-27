import ceylon.test {
    test,
    assertEquals
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    VisitorAdaptor,
    Ast=Tree
}

import test.org.eclipse.ceylon.ide.common.testUtils {
    parseAndTypecheckCode,
    SourceCode
}
shared test void invalidFunctionalParameterArgumentScope() {
    value pus = parseAndTypecheckCode {
        SourceCode {
            path="dir/test.ceylon";
            contents = "shared void test(
                            void functionalParameter(
                                Integer functionalParameterArgument)) {}";
        }
    };
    assert(exists cu = pus.items.first?.compilationUnit);
        object extends VisitorAdaptor() {
            shared actual void visitIdentifier(Ast.Identifier node) {
                if (node.text == "functionalParameterArgument") {
                    assertEquals {
                        message = "Wrong scope of functional parameter argument";
                        expected = "value test.functionalParameter.functionalParameterArgument => Integer";
                        actual = node.scope.string;
                    };
                }
            }
        }.visit(cu);
}

