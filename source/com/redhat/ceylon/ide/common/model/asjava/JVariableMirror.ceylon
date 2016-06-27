import com.redhat.ceylon.model.loader.mirror {
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value
}

class JVariableMirror(Parameter|Value p) satisfies VariableMirror {
    
    getAnnotation(String? string) => null;
    
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