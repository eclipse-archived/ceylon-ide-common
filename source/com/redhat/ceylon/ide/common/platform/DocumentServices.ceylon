import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import java.lang {
    StringBuilder
}

shared interface DocumentServices {

    shared formal TextChange createTextChange(String name, CommonDocument|PhasedUnit input);

    shared formal CompositeChange createCompositeChange(String name);

    shared formal Integer indentSpaces;

    shared formal Boolean indentWithSpaces;

    shared String defaultIndent {
        StringBuilder result = StringBuilder();
        initialIndent(result);
        return result.string;
    }

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
}