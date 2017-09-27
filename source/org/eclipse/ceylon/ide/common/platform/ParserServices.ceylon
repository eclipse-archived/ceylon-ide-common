import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonParser,
    CeylonLexer
}
import org.antlr.runtime {
    CommonTokenStream,
    ANTLRStringStream,
    CommonToken,
    TokenSource
}
import java.util {
    JList = List
}

shared interface ParserServices {
    shared formal CeylonLexer(ANTLRStringStream)? buildCustomizedLexer;
    shared formal CommonTokenStream(TokenSource)? buildCustomizedTokenStream;
    shared formal CeylonParser(CommonTokenStream)? buildCustomizedParser;
    shared formal JList<CommonToken>(TokenSource, CommonTokenStream)? buildCustomizedTokens;
}

shared class DefaultParserServices() satisfies ParserServices {
    shared actual default CeylonLexer(ANTLRStringStream)? buildCustomizedLexer = null;
    shared actual default CommonTokenStream(TokenSource)? buildCustomizedTokenStream = null;
    shared actual default CeylonParser(CommonTokenStream)? buildCustomizedParser = null;
    shared actual default JList<CommonToken>(TokenSource, CommonTokenStream)? buildCustomizedTokens = null;
}

shared object defaultParserServices extends DefaultParserServices() {}