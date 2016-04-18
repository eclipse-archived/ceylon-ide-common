import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.ide.common.correct {
    CommonDocument
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}

deprecated("Use [[commonIndents]] and [[CommonDocument]] instead.")
shared interface IndentsServicesConsumer<Document> {
    shared Indents<Document> indents => platformServices.indents<Document>();
}

shared object commonIndents satisfies Indents<CommonDocument> {
    
    getDefaultLineDelimiter(CommonDocument? document)
            => operatingSystem.newline;
    
    getLine(Node node, CommonDocument doc)
            => doc.getLineContent(node.token.line - 1);
    
    // TODO maybe put those two properties in PlatformServices
    indentSpaces => platformServices.indents<Anything>().indentSpaces;
    
    indentWithSpaces => platformServices.indents<Anything>().indentWithSpaces;
}
