import com.redhat.ceylon.model.typechecker.model {
    Value,
    Declaration
}
import com.redhat.ceylon.compiler.java.codegen {
    CodegenUtil
}
import java.util {
    ArrayList,
    List,
    Collections
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    ClassMirror,
    VariableMirror,
    TypeMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.loader {
    NamingBase
}

shared class JObjectMirror(shared actual Value decl) extends AbstractClassMirror(decl) {
    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => true;
    
    satisfiedTypes => decl.type.satisfiedTypes;
    
    supertype => decl.type.extendedType;
    
    name => super.name + "_";
    
    shared actual void scanExtraMembers(ArrayList<MethodMirror> methods) { 
        methods.add(GetMethod(this));
    }
}

class GetMethod(JObjectMirror obj) satisfies MethodMirror {
    shared actual Boolean abstract => false;
    
    shared actual Boolean constructor => false;
    
    shared actual Boolean declaredVoid => false;
    
    shared actual Boolean default => false;
    
    shared actual Boolean defaultAccess => false;
    
    shared actual ClassMirror enclosingClass => obj;
    
    shared actual Boolean final => true;
    
    shared actual AnnotationMirror? getAnnotation(String? string) => null;
    
    shared actual String name => NamingBase.Unfix.get_.string;
    
    shared actual List<VariableMirror> parameters
            => Collections.emptyList<VariableMirror>();
    
    shared actual Boolean protected => false;
    
    shared actual Boolean public => true;
    
    shared actual TypeMirror returnType => JTypeMirror(obj.decl.type);
    
    shared actual Boolean static => true;
    
    shared actual Boolean staticInit => false;
    
    shared actual List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    shared actual Boolean variadic => false;
}

shared String getJavaQualifiedName(Declaration decl) {
    value fqn = CodegenUtil.getJavaNameOfDeclaration(decl);
    if (is Value decl) {
        return fqn.initial(fqn.size - ".get_".size);
    }
    return fqn;
}
