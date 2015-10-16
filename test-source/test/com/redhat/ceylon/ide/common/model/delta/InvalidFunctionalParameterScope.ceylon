import ceylon.test {
    test,
    assertEquals
}

import com.redhat.ceylon.compiler.typechecker.tree {
    VisitorAdaptor,
    Ast=Tree
}

import test.com.redhat.ceylon.ide.common.testUtils {
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

