import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}
import java.lang {
    StringBuilder
}

shared interface Indents<IDocument> {

    """The eclipse implementation of [[getLine()|Indents.getLine]] should be :
           try {
               value region = doc.getLineInformation(node.token.line-1);
               String line = doc.get(region.getOffset(), region.length());
           } catch(BadLocationException ble) {
               return "";
           }

     """
    shared formal String getLine(Node? node, IDocument? doc);

    shared String getIndent(Node? node, IDocument? doc) {
        if (exists node,
            exists endToken=node.endToken,
            endToken.line!=0) {
            assert(exists doc);
                "This line is factorized method that replaces the following code
                 from the original Eclipse plugin code :

                     value region = doc.getLineInformation(node.token.line-1);
                     String line = doc.get(region.getOffset(), region.length());

                 "
                String line = getLine(node, doc);

                """
                   This line is the translation of the following Java code :

                       CharArray chars = line.toCharArray();
                       for (int i=0; i<chars.length; i++) {
                        if (chars[i]!='\t' && chars[i]!=' ') {
                            return line.substring(0,i);
                        }
                       }

                   """
                value result = String (
                            line.takeWhile(
                                (c) => c == '\t' || c == ' '));
                return result;
        } else {
            return "";
        }
    }

    shared String defaultIndent {
        StringBuilder result = StringBuilder();
        initialIndent(result);
        return result.string;
    }

    """The eclipse implementation of [[indentSpaces|Indents.indentSpaces]] should be :

            IPreferenceStore store = EditorsUI.getPreferenceStore();
            return store==null ? 4 : store.getInt(EDITOR_TAB_WIDTH);

       """
    shared formal Integer indentSpaces;

    """The eclipse implementation of [[indentWithSpaces|Indents.indentWithSpaces]] should be :

            IPreferenceStore store = EditorsUI.getPreferenceStore();
            return store==null ? false : store.getBoolean(EDITOR_SPACES_FOR_TABS);

       """
    shared formal Boolean indentWithSpaces;

    shared void initialIndent(StringBuilder buf) {
        //guess an initial indent level
        if (indentWithSpaces) {
            value spaces = indentSpaces;
            for (i in 1..spaces) {
                buf.append(' ');
            }
        }
        else {
            buf.append('\t');
        }
    }

    """The eclipse implementation of [[getDefaultLineDelimiter()|Indents.getDefaultLineDelimiter]] should be :

            if (document instanceof IDocumentExtension4) {
                return ((IDocumentExtension4) document).getDefaultLineDelimiter();
            }
            else {
                return System.lineSeparator();
            }

       """
    shared formal String getDefaultLineDelimiter(IDocument? document);
}
