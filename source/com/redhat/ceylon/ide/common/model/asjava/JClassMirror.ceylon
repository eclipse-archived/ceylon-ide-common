import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.ide.common.model.asjava {
    ceylonToJavaMapper {
        mapDeclaration
    }
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
    Class
}

import java.util {
    List,
    Collections,
    ArrayList
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}

shared class JClassMirror(shared ClassOrInterface decl) satisfies ClassMirror {
    
    variable Boolean initialized = false;
    
    late List<FieldMirror> fields;
    late List<MethodMirror> methods;
    
    shared actual Boolean abstract => decl.abstract;
    
    shared actual Boolean annotationType => decl.annotation;
    
    shared actual Boolean anonymous => decl.anonymous;
    
    shared actual Boolean ceylonToplevelAttribute => false;
    
    shared actual Boolean ceylonToplevelMethod => false;
    
    shared actual Boolean ceylonToplevelObject => false;
    
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
    
    shared actual Boolean final => decl.final;
    
    shared actual String flatName => qualifiedName.replace("::", ".");
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    shared actual String? getCacheKey(Module? \imodule) => null;
    
    shared actual Boolean innerClass => false;
    
    shared actual Boolean \iinterface => decl is Interface;
    
    shared actual List<TypeMirror> interfaces {
        value types = ArrayList<TypeMirror>();
        
        CeylonIterable(decl.satisfiedTypes).each((s) {
            types.add(JTypeMirror(s));
        });
        
        return types;
    }
    
    shared actual Boolean javaSource => false;
    
    shared actual Boolean loadedFromSource => false;
    
    shared actual Boolean localClass => false;
    
    shared actual String name => decl.name;
    
    shared actual PackageMirror? \ipackage => null;
    
    shared actual Boolean protected => false;
    
    shared actual Boolean public => decl.shared;
    
    shared actual String qualifiedName => decl.qualifiedNameString;
    
    shared actual Boolean static => false;
    
    shared actual TypeMirror? superclass => JTypeMirror(decl.extendedType);
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    void scanMembers() {
        synchronize(this, () {
            if (initialized) {
                return;
            }
            
            value members = CeylonIterable(decl.members)
                    .flatMap((m) => mapDeclaration(m));
            
            methods = ArrayList<MethodMirror>();
            members.each((e) {
                if (is MethodMirror e) {
                    methods.add(e); 
                }
            });
            
            initialized = true;            
        });
    }
}