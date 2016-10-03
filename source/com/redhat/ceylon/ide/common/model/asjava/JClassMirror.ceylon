import com.redhat.ceylon.ide.common.model.asjava {
    ceylonToJavaMapper {
        mapDeclaration
    }
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    TypeParameterMirror,
    FieldMirror,
    TypeMirror,
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    ClassOrInterface,
    Interface,
    Declaration,
    Type,
    Class
}

import java.lang {
    JString=String
}
import java.util {
    List,
    Collections,
    ArrayList
}

shared abstract class AbstractClassMirror(shared Declaration decl)
        satisfies ClassMirror & DeclarationMirror {
    
    variable Boolean initialized = false;
    
    late List<FieldMirror> fields;
    late List<MethodMirror> methods;
    late List<ClassMirror> innerClasses;

    declaration => decl;
    
    annotationType => decl.annotation;
    
    anonymous => decl.anonymous;
    
    defaultAccess => !decl.shared;
    
    shared actual List<FieldMirror> directFields {
        scanMembers();
        return fields;
    }
    
    shared actual List<ClassMirror> directInnerClasses {
        scanMembers();
        return innerClasses;
    }
    
    shared actual List<MethodMirror> directMethods {
        scanMembers();
        return methods;
    }
    
    enclosingClass => null;
    
    enclosingMethod => null;
    
    enum => decl.javaEnum;
    
    final => if (is ClassOrInterface d = decl) then d.final else true;
    
    flatName => qualifiedName.replace("::", ".");
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();
    
    getCacheKey(Module? \imodule) => null;
    
    innerClass => false;
    
    \iinterface => decl is Interface;
    
    shared actual List<TypeMirror> interfaces {
        value types = ArrayList<TypeMirror>();
        for (s in satisfiedTypes) {
            types.add(JTypeMirror(s));
        }
        return types;
    }
    
    javaSource => false;
    
    loadedFromSource => false;
    
    localClass => false;
    
    shared actual default String name => decl.name;
    
    \ipackage => null;
    
    protected => false;
    
    public => decl.shared;
    
    qualifiedName => javaQualifiedName(decl).replace("::", ".");
    
    static => false;
    
    superclass 
            => if (exists s = supertype) then JTypeMirror(s) else null;
    
    shared actual default List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    void scanMembers() {
        synchronize(this, () {
            if (initialized) {
                return;
            }
            
            value members
                    = { for (m in decl.members)
                        for (d in mapDeclaration(m))
                        d };
            
            innerClasses = ArrayList<ClassMirror>();
            methods = ArrayList<MethodMirror>();

            members.each((e) {
                if (is MethodMirror e) {
                    methods.add(e); 
                } else {
                    innerClasses.add(e);
                }
            });
            
            scanExtraMembers(methods);
            
            initialized = true;            
        });
    }
    
    shared default void scanExtraMembers(List<MethodMirror> methods)
            => noop();
    
    shared formal Type? supertype;
    shared formal List<Type> satisfiedTypes;
}

shared class JClassMirror(ClassOrInterface decl)
        extends AbstractClassMirror(decl) {
    
    abstract => decl.abstract;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => false;
    
    supertype => decl.extendedType;
    
    satisfiedTypes => decl.satisfiedTypes;
    
    shared default actual List<TypeParameterMirror> typeParameters {
        value types = ArrayList<TypeParameterMirror>();
        for (t in decl.typeParameters) {
            types.add(JTypeParameterMirror(t));
        }
        return types;
    }

    shared actual void scanExtraMembers(List<MethodMirror> methods) {
        super.scanExtraMembers(methods);

        if (is Class cl = decl,
            exists pl = cl.parameterList,
            !pl.parameters.empty) {
            
            methods.add(JConstructorMirror(cl, pl));
        }
    }
}