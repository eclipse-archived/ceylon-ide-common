import com.redhat.ceylon.ide.common.model {
    unknownTypeMirror
}
import com.redhat.ceylon.model.loader.mirror {
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value,
    Type
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
            else p.name;

    type => 
            let (Type? t = switch (p)
                           case (is Parameter) p.type
                           else p.type
            )
            if (exists t)
            then ceylonToJavaMapper.mapType(t)
            else unknownTypeMirror;
}