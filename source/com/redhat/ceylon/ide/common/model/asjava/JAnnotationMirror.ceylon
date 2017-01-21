import com.redhat.ceylon.model.loader.mirror {
    AnnotationMirror
}

shared class JAnnotationMirror(
    shared actual Object? getValue(String fieldName) => () => null,
    shared actual Object? \ivalue = null) satisfies AnnotationMirror {}




