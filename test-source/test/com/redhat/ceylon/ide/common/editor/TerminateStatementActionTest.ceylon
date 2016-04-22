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
    TextChange,
    DefaultTextChange,
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
        => testAndAssert("shared void run() {", 1, "shared void run() { }");

shared test void missingSemi()
        => testAndAssert("shared void run() {
                            print(1)
                          }",
    2,
    "shared void run() {
       print(1);
     }");

void testAndAssert(String code, Integer line, String expected) {
    testPlatform.register();
    value doc = DefaultDocument(code);
    
    TerminateStatementActionTest().terminateStatement(doc, line);
    
    assertEquals(doc.text, expected);
}

class TerminateStatementActionTest()
        satisfies AbstractTerminateStatementAction<DefaultDocument> {
    
    shared actual void applyChange(TextChange change) {
        if (is DefaultTextChange change) {
            change.applyChanges();
        }
    }
    
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
