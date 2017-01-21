import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.java.codegen {
    AbstractTransformer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.loader.mirror {
    TypeMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    ClassOrInterface,
    TypedDeclaration
}

import java.lang {
    JInteger=Integer,
    JBoolean=Boolean,
    JString=String
}
import java.util {
    Arrays
}

shared class CeylonAnnotations {
    static value typeSerialiser= AbstractTransformer.TypeSerializer();
    
    // Copied from `com.redhat.ceylon.compiler.java.codegen.AbstractTransformer.serialiseTypeSignature`
    // TODO This should be abstracted or made public API in the ceylon-compiler project to be reused here
    static String serialiseTypeSignature(variable Type type, Unit typeFact){
        // resolve aliases
        type = type.resolveAliases();
        return typeSerialiser.serialize(type, typeFact);
    }

    shared static CeylonAnnotations? classIfNecessary(Type? thisType, Type? extendedType, Boolean hasConstructors, Unit typeFact) {
        variable value isBasic = true;
        variable value isIdentifiable = true;
        value isAnything = 
                if(!exists extendedType,
            exists thisType ,
            thisType.isExactly(typeFact.anythingType))
        then true 
        else false;
        if(isAnything){
            // special for Anything
            isBasic = isIdentifiable = false;
        }else if(exists thisType){
            isBasic = thisType.getSupertype(typeFact.basicDeclaration) exists;
            // if isBasic, then isIdentifiable remains true
            if(!isBasic) {
                isIdentifiable = thisType.getSupertype(typeFact.identifiableDeclaration) exists;
            }
        }
        
        variable String? extendedTypeSig = null;
        if (isAnything) {
            extendedTypeSig = "";
        } else if (exists extendedType, !extendedType.isExactly(typeFact.basicType)){
            extendedTypeSig = serialiseTypeSignature(extendedType, typeFact);
        }
        
        value extendsType = javaString(extendedTypeSig else "");
        value basic = JBoolean(isBasic);
        value identifiable = JBoolean(isIdentifiable);
        value constructors = JBoolean(hasConstructors);
        value annotationFields = [extendsType, basic, identifiable, constructors];
        if (annotationFields == ["", JBoolean.true, JBoolean.true, JBoolean.false]) {
            // If all the valies are the default, the annotation will not be generated
            return null;
        }
        return class_(*annotationFields);
    }
    
    shared static CeylonAnnotations? typeInfoIfNecessary(TypedDeclaration decl, Boolean handleFunctionalParameter, CeylonToJavaMapper mapper) {
        return mapper.transformer.prepareTypeInfoAnnotation(decl, handleFunctionalParameter, mapper.javaTreeCreator);
    }

    shared static CeylonAnnotations? membersIfNecessary(ClassOrInterface decl, CeylonToJavaMapper mapper) {
        assert (is Tree.ClassOrInterface? def = mapper.declarationToNode(decl));
        return mapper.transformer.prepareMembersAnnotation(decl, def, mapper.javaTreeCreator);
    }
        
    shared JAnnotationMirror annotation;
    shared String fullyQualifiedName;
    
    shared new ceylon {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Ceylon";
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("major") JInteger(Versions.jvmBinaryMajorVersion)
            case("minor") JInteger(Versions.jvmBinaryMinorVersion)
            else null;
        };
    }
    
    shared new method {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Method";
        annotation = JAnnotationMirror {};
    }
    
    shared new ignore {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Ignore";
        annotation = JAnnotationMirror {};
    }
    
    shared new nonNull {
        fullyQualifiedName = "com.redhat.ceylon.common.NonNull";
        annotation = JAnnotationMirror {};
    }
    
    shared new class_(JString extendsType, JBoolean basic, JBoolean identifiable, JBoolean constructors) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Class";

        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("extendsType") extendsType
            case("basic") basic
            case("identifiable") identifiable
            case("constructors") constructors
            else null;
        };
    }
    
    shared new name(String val) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Name";
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("value") javaString(val)
            else null;
            
            \ivalue = val;
        };
    }
    
    shared new container(JClassMirror klassMirror) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Container";
        assert(exists enclosingClass = klassMirror.enclosingClass);
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("klass") klassMirror.mapper.mapType(enclosingClass)
            case("isStatic") JBoolean(klassMirror.static)
            else null;
        };
    }

    shared new typeInfo(String type, Boolean erased, Boolean declaredVoid, Boolean untrusted, Boolean uncheckedNull) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.TypeInfo";
        value theValue = javaString(type);
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("value") theValue
            case("erased") JBoolean(erased)
            case("declaredVoid") JBoolean(erased)
            case("untrusted") JBoolean(untrusted)
            case("uncheckedNull") JBoolean(uncheckedNull)
            else null;
            \ivalue = theValue;
        };
    }

    shared new member(String | TypeMirror type, CeylonToJavaMapper mapper) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Member";
        JString? javaClassName;
        TypeMirror? klass;
        if (is String type) {
            javaClassName = javaString(type);
            klass = null;
        } else {
            klass = type;
            javaClassName = null;
        }
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("klass") klass
            case("javaClassName") javaClassName
            else null;
        };
    }

    shared new members({AnnotationMirror*} members) {
        fullyQualifiedName = "com.redhat.ceylon.compiler.java.metadata.Members";
        value theValue = Arrays.asList(*members);
        annotation = JAnnotationMirror {
            getValue(String name) => switch(name)
            case("value") theValue
            else null;
            \ivalue = theValue;
        };
    }
    
    shared <String->JAnnotationMirror> entry => fullyQualifiedName->annotation;
}