import org.eclipse.ceylon.ide.common.platform {
    DocumentServices,
    DefaultCompositeChange,
    DefaultDocument,
    DefaultTextChange,
    CommonDocument
}
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}

object testDocumentServices satisfies DocumentServices {
    createCompositeChange(String desc)
            => DefaultCompositeChange(desc);
    
    shared actual DefaultTextChange createTextChange(String desc, CommonDocument|PhasedUnit input) {
        assert(is DefaultDocument input);
        return DefaultTextChange(input);
    }
    
    indentSpaces => 4;
    
    indentWithSpaces => true;
}