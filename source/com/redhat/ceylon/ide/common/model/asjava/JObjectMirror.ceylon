import com.redhat.ceylon.compiler.java.codegen {
    CodegenUtil
}
import com.redhat.ceylon.model.loader {
    NamingBase
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value,
    Declaration,
    Function,
    Type
}

import java.lang {
    JString=String
}
import java.util {
    ArrayList,
    Collections
}

shared class JObjectMirror(Value decl)
        extends AbstractClassMirror(decl) {

    shared Type type => decl.type;

    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => true;
    
    satisfiedTypes => type.satisfiedTypes;
    
    supertype => type.extendedType;
    
    name => super.name + "_";
    
    scanExtraMembers(ArrayList<MethodMirror> methods)
            => methods.add(GetMethod(this));
}

shared class GetMethod(JObjectMirror obj)
        satisfies MethodMirror {

    abstract => false;
    
    constructor => false;
    
    declaredVoid => false;
    
    default => false;
    
    defaultAccess => false;
    
    enclosingClass => obj;
    
    final => true;
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    name => NamingBase.Unfix.get_.string;
    
    parameters
            => Collections.emptyList<VariableMirror>();
    
    protected => false;
    
    public => true;
    
    returnType => ceylonToJavaMapper.mapType(obj.type);
    
    static => true;
    
    staticInit => false;
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    defaultMethod => false;
}

shared String getJavaQualifiedName(Declaration decl) {
    if (is Function decl, decl.toplevel, exists name = decl.name) {
        return decl.scope.qualifiedNameString + "." + name + "_";
    }
    value fqn = CodegenUtil.getJavaNameOfDeclaration(decl);
    return decl is Value then fqn.removeTerminal(".get_") else fqn;
}
