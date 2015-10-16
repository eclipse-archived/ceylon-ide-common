import ceylon.language.meta {
    type
}
import ceylon.test {
    test,
    assertEquals,
    AssertionComparisonError
}

import com.redhat.ceylon.compiler.typechecker.tree {
    VisitorAdaptor,
    Ast=Tree,
    TreeUtil
}
import com.redhat.ceylon.model.typechecker.model {
    Function,
    Declaration
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
                        expected = "function test.functionalParameter(Integer functionalParameterArgument) => Anything";
                        actual = node.scope.string;
                    };
                }
            }
        }.visit(cu);
}

