import ceylon.test {
    test,
    assertEquals
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.editor {
    AbstractTerminateStatementAction
}
import com.redhat.ceylon.ide.common.platform {
    DefaultDocument
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken,
    ANTLRStringStream,
    CommonTokenStream
}

import test.com.redhat.ceylon.ide.common.platform {
    testPlatform
}

shared test void missingBraceInFunction()
        => testAndAssert {
                code = "shared void run() {";
                line = 1;
                expected = "shared void run() { }";
                // newSelectionStart = 21;
            };

shared test void missingSemi()
        => testAndAssert {
                code = "shared void run() {
                            print(1)
                        }";
                line = 2;
                expected = "shared void run() {
                                print(1);
                            }";
                newSelectionStart = 33;
            };

shared test void missingFunctionBody()
        => testAndAssert {
                code = "shared void run()";
                line = 2;
                expected = "shared void run() {}";
                newSelectionStart = 19;
            };

void testAndAssert(String code, Integer line, String expected, Integer? newSelectionStart = null) {
    testPlatform.register();
    value doc = DefaultDocument(code);
    
    value reg = TerminateStatementActionTest().terminateStatement(doc, line);
    
    assertEquals(doc.text, expected);
    
    if (exists newSelectionStart) {
        assertEquals(reg?.start, newSelectionStart);
    }
}

class TerminateStatementActionTest()
        extends AbstractTerminateStatementAction<DefaultDocument>() {
    
    shared actual [Tree.CompilationUnit, List<CommonToken>] parse(DefaultDocument doc) {
        value stream = ANTLRStringStream(doc.text);
        value lexer = CeylonLexer(stream);
        value tokenStream = CommonTokenStream(lexer);
        value parser = CeylonParser(tokenStream);
        value cu = parser.compilationUnit();
        
        value toks = unsafeCast<List<CommonToken>>(tokenStream.tokens);
        
        return [cu, toks];
    }
}
