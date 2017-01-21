import ceylon.language.meta.model {
    CallableConstructor,
    ValueConstructor
}

import com.redhat.ceylon.model.loader {
    LanguageAnnotation
}
import com.redhat.ceylon.model.loader.mirror {
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Annotation,
    Annotated
}

import java.lang {
    JString=String
}
import java.util {
    Collections,
    Arrays
}

shared class LanguageAnnotations {
    static variable Map<String, LanguageAnnotations|CallableConstructor<LanguageAnnotations,[Annotation, Annotated]>>? mirrorBuilders_ = null;
    
    static CallableConstructor<LanguageAnnotations, [Annotation, Annotated]> toConstructor(LanguageAnnotation la) {
        value constructor = `LanguageAnnotations`.getConstructor<[Annotation, Annotated]>(la.name);
        
        "Missing constructor for a Language Annotation that is not a modifier"
        assert(exists constructor);
        
        "Missing constructor for a Language Annotation that is not a modifier"
        assert(! is ValueConstructor<LanguageAnnotations> constructor);
        
        return constructor;
    }
    
    static value mirrorBuilders => mirrorBuilders_ else (mirrorBuilders_ = map {
        for (la in LanguageAnnotation.values())
        la.name ->( 
            if (la.modifier)
            then LanguageAnnotations.create(la)
            else toConstructor(la)
        )
    });
    
    shared static LanguageAnnotations? fromLanguageAnnotation(Annotation modelAnnotation, Annotated annotated) {
        return switch (mirrorBuilder = mirrorBuilders[modelAnnotation.name])
        case (is Null) null
        case (is LanguageAnnotations) mirrorBuilder
        else mirrorBuilder.apply(modelAnnotation, annotated);
    }
        
    static function convertPositionalArguments<Result>(Annotation modelAnnotation, Result(JString) convertEachArg)
                given Result satisfies Object =>
            Arrays.asList(for (pa in modelAnnotation.positionalArguments) convertEachArg(pa));
        
    shared JAnnotationMirror annotationMirror;
    shared String fullyQualifiedName;
    shared String ceylonSimpleName;
    LanguageAnnotation languageAnnotation;
    
    shared new create(LanguageAnnotation languageAnnotation, JAnnotationMirror annotation = JAnnotationMirror()) {
        fullyQualifiedName = languageAnnotation.annotationType;
        ceylonSimpleName = languageAnnotation.name;
        this.annotationMirror = annotation;
        this.languageAnnotation = languageAnnotation;
    }
    
    shared new doc(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.doc,
        JAnnotationMirror {
            getValue(String name) => name == "description" then
            modelAnnotation.positionalArguments.get(0);
        }) {}

    shared new throws(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.throws,
        JAnnotationMirror {
            getValue(String name) => name == "value" then
            Collections.emptyList<AnnotationMirror>();
            \ivalue = Collections.emptyList<AnnotationMirror>();
        }) {}

    shared new by(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.by,
        JAnnotationMirror {
            getValue(String name) => name == "authors" then 
            convertPositionalArguments(modelAnnotation, identity);
            \ivalue = convertPositionalArguments(modelAnnotation, identity);
        }) {}

    shared new native(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.native,
        JAnnotationMirror {
            getValue(String name) => if (name == "backends", 
                exists pas = modelAnnotation.positionalArguments,
                !pas.empty)
            then convertPositionalArguments(modelAnnotation, identity)
            else null;
        }) {}

    shared new see(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.see,
        JAnnotationMirror {
            getValue(String name) => name == "value" then
            Collections.emptyList<AnnotationMirror>();
            \ivalue = Collections.emptyList<AnnotationMirror>();
        }) {}

    shared new license(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.license,
        JAnnotationMirror {
            getValue(String name) => name == "description" then
            modelAnnotation.positionalArguments.get(0);
        }) {}
            
    shared new deprecated(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.deprecated,
        JAnnotationMirror {
            getValue(String name) => name == "description" then
            modelAnnotation.positionalArguments.get(0);
        }) {}
        
    shared new tagged(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.native,
        JAnnotationMirror {
            getValue(String name) => if (name == "tags", 
                exists pas = modelAnnotation.positionalArguments)
            then convertPositionalArguments(modelAnnotation, identity)
            else Collections.emptyList<JString>();
        }) {}
        
    shared new suppressWarnings(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.suppressWarnings,
        JAnnotationMirror {
            getValue(String name) => if (name == "warnings", 
                exists pas = modelAnnotation.positionalArguments)
            then convertPositionalArguments(modelAnnotation, identity)
            else Collections.emptyList<JString>();
        }) {}
        
    shared new aliased(Annotation modelAnnotation, Annotated annotated) extends create(
        LanguageAnnotation.aliases,
        JAnnotationMirror {
            getValue(String name) => if (name == "aliases", 
                exists pas = modelAnnotation.positionalArguments)
            then convertPositionalArguments(modelAnnotation, identity)
            else Collections.emptyList<JString>();
        }) {}
        
        
    shared <String->JAnnotationMirror> entry => fullyQualifiedName->annotationMirror;
}