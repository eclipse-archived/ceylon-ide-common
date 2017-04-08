import java.util {
    List,
    Collections
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.loader.mirror {
    AnnotationMirror,
    ClassMirror,
    FieldMirror,
    MethodMirror,
    PackageMirror,
    TypeMirror,
    TypeParameterMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Module,
    Scope,
    Class,
    Interface,
    TypeDeclaration,
    Package
}
import java.lang {
    IllegalAccessError,
    JString=String,
    Types {
        nativeString
    }
}

shared class SourceClass satisfies ClassMirror {
    SourceDeclarationHolder sourceDeclarationHolder;
    variable String? _cacheKey = null;
    variable String? _qualifiedName = null;
    variable String? _flatName = null;
    
    shared new (SourceDeclarationHolder sourceDeclarationHolder) {
        this.sourceDeclarationHolder = sourceDeclarationHolder;
    }
    
    throws(`class IllegalAccessError`)
    shared actual AnnotationMirror getAnnotation(String type) {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    annotationNames => Collections.emptySet<JString>();
    
    shared actual Boolean public =>
            modelDeclaration.shared;
    
    shared actual Boolean \iinterface =>
            modelDeclaration is Interface;
    
    shared actual Boolean abstract =>
            let(decl = modelDeclaration)
            if (is Class decl) 
            then decl.abstract 
            else false;
    
    shared actual Boolean protected => false;
    
    shared actual Boolean defaultAccess => false;
    
    shared actual Boolean static => modelDeclaration.static;
    
    shared actual Boolean enum => false;
    
    shared actual Boolean final =>
            let(decl = modelDeclaration)
            if (is TypeDeclaration decl) 
            then decl.final
            else false;
    
    shared actual Boolean innerClass =>
            modelDeclaration.classOrInterfaceMember;
    
    shared actual Boolean anonymous {
        return modelDeclaration.anonymous;
    }
    
    shared actual String name =>
            modelDeclaration.name;
    
    shared actual String? qualifiedName {
        if (! _qualifiedName exists ) {
            String? ceylonQualifiedName = modelDeclaration.qualifiedNameString;
            if (exists ceylonQualifiedName) {
                _qualifiedName = ceylonQualifiedName.replace("::", ".");
            }
        }
        
        return _qualifiedName;
    }
    
    shared actual String? flatName {
        if (! _flatName exists ) {
            String? ceylonQualifiedName = modelDeclaration.qualifiedNameString;
            if (exists ceylonQualifiedName) {
                value packageAndDecl = nativeString(ceylonQualifiedName).split("::");
                value declName = packageAndDecl.get(packageAndDecl.size - 1).replace('.', '$');
                if (packageAndDecl.size > 1) {
                    _flatName = "``packageAndDecl.get(0)``.``declName``";
                } else {
                    _flatName = declName;
                }
            }
        }
        
        return _flatName;
    }
    
    function findPackage() {
        value decl = modelDeclaration;
        variable Scope? scope = decl.container;
        while (exists s=scope) {
            if (is Package s) {
                return s;
            }
            scope = s.container;
        }
        return null;
    }
    
    shared actual PackageMirror \ipackage => 
            object satisfies PackageMirror {
                qualifiedName = 
                        if (exists p=findPackage()) 
                        then p.qualifiedNameString 
                        else "";
            };
    
    shared actual List<MethodMirror> directMethods {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual List<FieldMirror> directFields {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual List<TypeParameterMirror> typeParameters {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual List<ClassMirror> directInnerClasses {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual ClassMirror enclosingClass {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual MethodMirror enclosingMethod {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual TypeMirror superclass {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual List<TypeMirror> interfaces {
        throw IllegalAccessError("Don't use a Source Class Mirror !");
    }
    
    shared actual Boolean ceylonToplevelAttribute => 
            astDeclaration is Tree.AttributeDeclaration 
            && modelDeclaration.toplevel;
    
    shared actual Boolean ceylonToplevelObject =>
            astDeclaration is Tree.ObjectDefinition 
            && modelDeclaration.toplevel;
    
    shared actual Boolean ceylonToplevelMethod =>
            astDeclaration is Tree.MethodDefinition 
            && modelDeclaration.toplevel;
    
    shared Declaration modelDeclaration {
        assert (exists md = sourceDeclarationHolder.modelDeclaration);
        return md; 
    }
    
    shared Tree.Declaration astDeclaration =>
            sourceDeclarationHolder.astDeclaration;
    
    shared actual Boolean loadedFromSource => true;
    
    shared actual Boolean javaSource => false;
    
    shared actual Boolean annotationType => false;
    
    shared actual Boolean localClass => 
            !modelDeclaration.classOrInterfaceMember 
            && !modelDeclaration.toplevel;
    
    shared actual String? getCacheKey(Module mod) {
        if (! _cacheKey exists) {
            value className = qualifiedName;
            _cacheKey = AbstractModelLoader.getCacheKeyByModule(mod, className);
        }
        
        return _cacheKey;
    }
}
