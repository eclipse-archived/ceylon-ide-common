import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror,
    ClassMirror,
    AnnotationMirror,
    TypeKind
}
import com.redhat.ceylon.model.typechecker.model {
    Function
}

import java.util {
    List,
    Collections,
    ArrayList
}

shared class JMethodMirror(Function fun, ClassMirror? enclosingClass, mapper)
        extends AbstractMethodMirror<Function>(fun, enclosingClass) {
    
    shared actual CeylonToJavaMapper mapper;
    variable Integer? flags_ = null;
    
    flags => flags_ else 
    (flags_ = mapper.transformer.modifierTransformation().method(fun));

    abstract => super.abstract ||
            (if (exists enclosingClass)
                    then enclosingClass.\iinterface else false);
     
    constructor => false;
    
    declaredVoid => returnType.kind == TypeKind.\ivoid;
    
    name => declaration.name;
    
    shared actual List<VariableMirror> parameters {
        value vars = ArrayList<VariableMirror>();
        for (p in declaration.firstParameterList.parameters) {
            vars.add(JParameterMirror(p, mapper));
        }
        return vars;
    }
    
    returnType => mapper.transformer.prepareResultType(fun, 0, mapper.javaTreeCreator);
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => declaration.variadic;
    
    defaultMethod => false;
    
    static => declaration.toplevel then true else super.static;
    
    shared actual default {<String->AnnotationMirror>*} ceylonAnnotations => super.ceylonAnnotations.chain {
        if (exists classAnnotation = CeylonAnnotations.typeInfoIfNecessary(fun, false, mapper))
            classAnnotation.entry
    }.chain {
        if (fun.toplevel) CeylonAnnotations.method.entry
    };
}
