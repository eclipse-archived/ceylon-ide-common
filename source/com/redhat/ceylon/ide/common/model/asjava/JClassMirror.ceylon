import ceylon.interop.java {
    CeylonIterable
}

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
    PackageMirror,
    TypeMirror,
    MethodMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    ClassOrInterface,
    Interface,
    Declaration,
    Type
}

import java.util {
    List,
    Collections,
    ArrayList
}

shared abstract class AbstractClassMirror(shared default Declaration decl) satisfies ClassMirror {
    variable Boolean initialized = false;
    
    late List<FieldMirror> fields;
    late List<MethodMirror> methods;
    
    shared actual Boolean annotationType => decl.annotation;
    
    shared actual Boolean anonymous => decl.anonymous;
    
    shared actual Boolean defaultAccess => !decl.shared;
    
    shared actual List<FieldMirror> directFields {
        scanMembers();
        return fields;
    }
    
    shared actual List<ClassMirror> directInnerClasses 
            => Collections.emptyList<ClassMirror>();
    
    shared actual List<MethodMirror> directMethods {
        scanMembers();
        return methods;
    }
    
    shared actual ClassMirror? enclosingClass => null;
    
    shared actual MethodMirror? enclosingMethod => null;
    
    shared actual Boolean enum => decl.javaEnum;
    
    shared actual Boolean final => if (is ClassOrInterface d = decl) then d.final else true;
    
    shared actual String flatName => qualifiedName.replace("::", ".");
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    shared actual String? getCacheKey(Module? \imodule) => null;
    
    shared actual Boolean innerClass => false;
    
    shared actual Boolean \iinterface => decl is Interface;
    
    shared actual List<TypeMirror> interfaces {
        value types = ArrayList<TypeMirror>();
        
        CeylonIterable(satisfiedTypes).each((s) {
            types.add(JTypeMirror(s));
        });
        
        return types;
    }
    
    shared actual Boolean javaSource => false;
    
    shared actual Boolean loadedFromSource => false;
    
    shared actual Boolean localClass => false;
    
    shared actual default String name => decl.name;
    
    shared actual PackageMirror? \ipackage => null;
    
    shared actual Boolean protected => false;
    
    shared actual Boolean public => decl.shared;
    
    shared actual String qualifiedName => getJavaQualifiedName(decl);
    
    shared actual Boolean static => false;
    
    shared actual TypeMirror? superclass 
            => if (exists s = supertype) then JTypeMirror(s) else null;
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    void scanMembers() {
        synchronize(this, () {
            if (initialized) {
                return;
            }
            
            value members = CeylonIterable(decl.members)
                    .flatMap((m) => mapDeclaration(m));
            
            value _methods = ArrayList<MethodMirror>();
            methods = _methods;
            members.each((e) {
                if (is MethodMirror e) {
                    methods.add(e); 
                }
            });
            
            scanExtraMembers(_methods);
            
            initialized = true;            
        });
    }
    
    shared default void scanExtraMembers(ArrayList<MethodMirror> methods) {
        
    }
    
    shared formal Type? supertype;
    shared formal List<Type> satisfiedTypes;
}

shared class JClassMirror(shared actual ClassOrInterface decl) extends AbstractClassMirror(decl) {
    
    abstract => decl.abstract;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => false;
    
    supertype => decl.extendedType;
    
    satisfiedTypes => decl.satisfiedTypes;
}