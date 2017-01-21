import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.model.loader.mirror {
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

import java.util {
    HashSet
}

shared abstract class DeclarationMirror<DeclarationType>(DeclarationType decl) 
        extends ModelBasedAnnotationMirror()
    satisfies DeclarationBasedMirror<DeclarationType>
        given DeclarationType satisfies Declaration {
    
    shared actual DeclarationType declaration = decl;

    shared actual default {<String->AnnotationMirror>*} ceylonAnnotations => {
            *concatenate({
                if(rules.annotations.addTheCeylonAnnotation(declaration)) CeylonAnnotations.ceylon.entry
            })
        };
        
    shared actual default {<String->AnnotationMirror>*} externalAnnotations {
        return
        let(alreadySeenLanguageAnnotations = HashSet<String>())
        { for (a in declaration.annotations)
            if(exists la = LanguageAnnotations.fromLanguageAnnotation(a, declaration),
                alreadySeenLanguageAnnotations.add(a.name))
            then la.entry
            else a.name -> JAnnotationMirror { 
                function getValue(String fieldName) => a.namedArguments.get(javaString(fieldName));
                \ivalue = null;
            }
        };
    }
}