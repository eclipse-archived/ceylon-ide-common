import com.redhat.ceylon.model.loader.mirror {
    AnnotationMirror,
    AnnotatedMirror
}
import ceylon.interop.java {
    JavaSet,
    javaString
}
import java.lang {
    JString=String
}

shared abstract class ModelBasedAnnotationMirror() 
        satisfies ModelBasedMirror &
                    AnnotatedMirror {
    
    variable JavaSet<JString>? annotationNames_ = null;
    variable  [<String->AnnotationMirror>*]? annotations_ = null;

    shared formal {<String->AnnotationMirror>*} ceylonAnnotations;
    shared formal {<String->AnnotationMirror>*} externalAnnotations;
    
    shared [<String->AnnotationMirror>*] annotations => annotations_ else 
    (annotations_ = ceylonAnnotations.chain(externalAnnotations).sequence());
    
    getAnnotation(String name) =>
            annotations.find((key -> item) => key == name)?.item;
    
    annotationNames => 
            annotationNames_ else
            (annotationNames_ = JavaSet(set(annotations*.key.map(javaString))));
}