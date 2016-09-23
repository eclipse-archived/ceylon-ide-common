import com.redhat.ceylon.ide.common.model {
    unknownTypeMirror
}
import com.redhat.ceylon.model.loader.mirror {
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value
}

import java.lang {
    JString=String
}
import java.util {
    Collections
}

class JVariableMirror(Parameter|Value p) satisfies VariableMirror {
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    name => 
            switch (p)
            case (is Parameter) p.name
            case (is Value) p.name;

    type =>
            if (exists t
                    = switch (p)
                    case (is Parameter) p.type
                    case (is Value) p.type)
            then ceylonToJavaMapper.mapType(t)
            else unknownTypeMirror;
}