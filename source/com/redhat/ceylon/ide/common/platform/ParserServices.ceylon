import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonParser,
    CeylonLexer
}
import org.antlr.runtime {
    CommonTokenStream,
    ANTLRStringStream,
    CommonToken
}
import java.util {
    JList = List
}

shared interface ParserServices {
    shared formal CeylonLexer(ANTLRStringStream)? buildCustomizedLexer;
    shared formal  CommonTokenStream(CeylonLexer)? buildCustomizedTokenStream;
    shared formal CeylonParser(CommonTokenStream)? buildCustomizedParser;
    shared formal JList<CommonToken>(CeylonLexer, CommonTokenStream)? buildCustomizedTokens;
}

shared class DefaultParserServices() satisfies ParserServices {
    shared actual default CeylonLexer(ANTLRStringStream)? buildCustomizedLexer = null;
    shared actual default CommonTokenStream(CeylonLexer)? buildCustomizedTokenStream = null;
    shared actual default CeylonParser(CommonTokenStream)? buildCustomizedParser = null;
    shared actual default JList<CommonToken>(CeylonLexer, CommonTokenStream)? buildCustomizedTokens = null;
}

shared object defaultParserServices extends DefaultParserServices() {}