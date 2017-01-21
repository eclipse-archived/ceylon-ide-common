import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.java.codegen {
    Strategy
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.langtools.tools.javac.code {
    Flags
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror,
    ClassMirror,
    AnnotationMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Class,
    ParameterList,
    Constructor
}

import java.lang {
    JString=String
}
import java.util {
    List,
    Collections,
    Arrays
}

class JConstructorMirror(Constructor decl, ClassMirror classMirror, mapper)
        extends DeclarationMirror<Constructor>(decl)
        satisfies MethodMirror {
    
    shared actual CeylonToJavaMapper mapper;
    variable List<VariableMirror>? parameters_ = null;
    assert(is JClassMirror classMirror);
    assert(is Class klass = classMirror.declaration);
    
    value visibility = rules.classMirror.constructors.visibility(klass);
    value thisHiddenParameter = rules.classMirror.constructors.addHiddenThisParameter(klass) then
    object satisfies VariableMirror {
        assert(exists enclosingClass = classMirror.enclosingClass);
        type = mapper.mapType(enclosingClass);
        annotationNames = Collections.emptySet<JString>();
        name = "unknown";
        getAnnotation(String? type) => null;
    };
    
    name => "<init>";
    
    abstract => false;
    constructor => true;
    declaredVoid => false;
    default => false;
    defaultMethod => false;
    enclosingClass => classMirror;
    final => false;
    
    function buildParameters() 
        => let(ceylonParameters = 
        if (exists pl=declaration.parameterList) 
        then CeylonIterable(pl.parameters) else [])
        Arrays.asList(
            *concatenate(
                {
                    if (exists thisHiddenParameter) thisHiddenParameter
                },
                {
                    for (p in ceylonParameters)
                    JParameterMirror(p, mapper) of VariableMirror
                }
            )
        );
    
    parameters => parameters_ else (parameters_ = buildParameters());
    
    defaultAccess => visibility == JavaVisibility.packagePrivate;
    protected => visibility == JavaVisibility.protected;
    public => visibility == JavaVisibility.public;
    
    returnType => mapper.mapType(classMirror);
    
    static => false;
    
    staticInit => false;
    
    typeParameters => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
}

class AdditionalParameter(name, type, ceylonAnnotations, mapper)
        extends ModelBasedAnnotationMirror()
        satisfies VariableMirror {
    shared actual CeylonToJavaMapper mapper;
    shared actual String name;
    shared actual TypeMirror type;
    shared actual {<String->JAnnotationMirror>*} ceylonAnnotations;
    externalAnnotations = [];
}

class JClassParameterListMirror(Class cls, ClassMirror classMirror, ParameterList pl, mapper)
        extends ModelBasedAnnotationMirror()
        satisfies MethodMirror & ModelBasedAccessibleMirror {
    
    shared actual CeylonToJavaMapper mapper;
    variable List<VariableMirror>? parameters_ = null;

    variable Integer? flags_ = null;
    
    "takes the rules from the calls to `getInitBuilder().modifiers()` 
     in `ClassTransformer.transform(ClassOrInterface)`"
    function buildFlags() {
        variable value theFlags = mapper.transformer.modifierTransformation().constructor(cls);
        
        assert (is Tree.AnyClass classDef = mapper.declarationToNode(cls));
        // Member classes need a instantiator method
        value generateInstantiator = Strategy.generateInstantiator(cls);
        if(generateInstantiator
            && !cls.hasConstructors()
                && !cls.hasEnumerated()){
            if (!cls.static) {
                theFlags = Flags.protected;
            }
        }
        
        if(! classDef is Tree.ClassDefinition){
            // class alias
            theFlags = Flags.private;
        }        
        return theFlags;
    }
    
    flags => flags_ else (flags_ = buildFlags());
    
    name => "<init>";
    
    abstract => false;
    constructor => true;
    declaredVoid => false;
    default => false;
    defaultMethod => false;
    enclosingClass => classMirror;
    final => false;
    
    parameters => parameters_ else (parameters_ = Arrays.asList(
            *concatenate(
                { 
                    if (rules.classMirror.constructors.addHiddenThisParameter(cls))
                        AdditionalParameter {
                            mapper = this.mapper;
                            name = "unknown";
                            type = mapper.mapType(classMirror);
                        }
                },
                {
                    for (tp in Strategy.getEffectiveTypeParameters(cls))
                        AdditionalParameter {
                            mapper = this.mapper;
                            name = mapper.naming.getTypeArgumentDescriptorName(tp);
                            type = mapper.javaTreeCreator.typeDescriptorTypeIdent();
                            ceylonAnnotations = {
                                CeylonAnnotations.ignore.entry,
                                CeylonAnnotations.nonNull.entry
                            };
                        }
                },
                {
                    for (p in pl.parameters)
                        JParameterMirror(p, mapper) of VariableMirror
                })
        ));
    
    returnType => mapper.mapType(classMirror);
    
    static => false;
    
    staticInit => false;
    
    typeParameters => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    shared actual {<String->AnnotationMirror>*} ceylonAnnotations => [];
    
    shared actual {<String->AnnotationMirror>*} externalAnnotations => [];
    
}
