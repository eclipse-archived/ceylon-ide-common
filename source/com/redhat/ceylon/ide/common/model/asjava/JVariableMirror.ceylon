import com.redhat.ceylon.model.loader.mirror {
    VariableMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    Value
}

class JSetterParameterMirror(Value p, mapper) 
        extends ModelBasedAnnotationMirror()
        satisfies VariableMirror {
    
    shared actual CeylonToJavaMapper mapper;
    name = p.name;

    // Review this: this is not exactly the sae as in the backend code
    type => mapper.transformer.prepareJavaType(p, p.type, 0, mapper.javaTreeCreator);
    
    shared actual {<String->AnnotationMirror>*} ceylonAnnotations => [] ;
    shared actual {<String->AnnotationMirror>*} externalAnnotations => [];
}

class JParameterMirror(Parameter p, mapper) 
        extends ModelBasedAnnotationMirror()
        satisfies VariableMirror {
    shared actual CeylonToJavaMapper mapper;
    
    name => p.name; 
    
    type => mapper.transformer.prepareJavaType(p.model, p.type, 0, mapper.javaTreeCreator);
    
    shared actual {<String->AnnotationMirror>*} ceylonAnnotations => { 
        CeylonAnnotations.name(name).entry,
        * { if (exists typeInfo = CeylonAnnotations.typeInfoIfNecessary(p.model, true, mapper))
            typeInfo.entry
        }
    };
    shared actual {<String->AnnotationMirror>*} externalAnnotations => [];
}