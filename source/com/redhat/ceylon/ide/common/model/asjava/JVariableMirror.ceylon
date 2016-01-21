import com.redhat.ceylon.model.loader.mirror {
    VariableMirror,
    TypeMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value
}

class JVariableMirror(Parameter|Value p) satisfies VariableMirror {
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    shared actual String name => 
            switch (p)
            case (is Parameter) p.name
            else p.name;

    shared actual TypeMirror type => ceylonToJavaMapper.mapType(
        switch (p)
        case (is Parameter) p.type
        else p.type
    );
}