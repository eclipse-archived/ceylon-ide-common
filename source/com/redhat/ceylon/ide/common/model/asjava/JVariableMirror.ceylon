import com.redhat.ceylon.model.loader.mirror {
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value
}
import java.util {
    Collections
}
import java.lang {
    JString=String
}

class JVariableMirror(Parameter|Value p) satisfies VariableMirror {
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    name => 
            switch (p)
            case (is Parameter) p.name
            else p.name;

    type => ceylonToJavaMapper.mapType(
        switch (p)
        case (is Parameter) p.type
        else p.type
    );
}