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
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
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

import test.com.redhat.ceylon.ide.common.correct {
    InsertEdit,
    TextEdit,
    TextChange,
    CommonDocumentChanges,
    Ref
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
    value ref = Ref<String>(code);
    
    TerminateStatementAction().terminateStatement(ref, line);
    
    assertEquals(ref.val, expected);
}

class TerminateStatementAction()
        satisfies AbstractTerminateStatementAction
        <Ref<String>, InsertEdit, TextEdit, TextChange>
        & CommonDocumentChanges {
    
    shared actual void applyChange(TextChange change) {
        change.applyChanges();
    }
    
    shared actual Boolean hasChildren(TextChange change)
            => change.hasChanges;
    
    shared actual TextChange newChange(String desc, Ref<String> doc) 
            => TextChange(doc);
    
    shared actual [Tree.CompilationUnit, List<CommonToken>] parse(Ref<String> doc) {
        value stream = ANTLRStringStream(doc.val);
        value lexer = CeylonLexer(stream);
        value tokenStream = CommonTokenStream(lexer);
        value parser = CeylonParser(tokenStream);
        value cu = parser.compilationUnit();
        
        value toks = unsafeCast<List<CommonToken>>(tokenStream.tokens);
        
        return [cu, toks];
    }
    
    shared actual [DefaultRegion, String] getLineInfo(Ref<String> doc, Integer line) {
        value lines = doc.val.split('\n'.equals).sequence();
        
        value startOffset = if (line > 1) 
                then sum({ for (i in 0..line - 2) (lines[i]?.size else 0) + 1 })
                else 0;

        value l = lines[line - 1] else "";
        return [DefaultRegion(startOffset, l.size), l];
    }
    
    shared actual Character getChar(Ref<String> doc, Integer offset)
        => doc.val[offset] else ' ';
}
