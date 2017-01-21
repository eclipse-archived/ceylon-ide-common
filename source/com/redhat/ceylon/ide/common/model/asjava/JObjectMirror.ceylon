import com.redhat.ceylon.compiler.java.codegen {
    CodegenUtil
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status
}
import com.redhat.ceylon.model.loader {
    NamingBase
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror,
    ClassMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value,
    Declaration,
    Type,
    FunctionOrValue,
    Package,
    TypeDeclaration
}

import java.lang {
    JString=String,
    IllegalArgumentException
}
import java.util {
    List,
    Collections
}

shared class JObjectMirror(Value decl, ClassMirror? enclosingClass, mapper)
        extends AbstractClassMirror<TypeDeclaration>(decl.typeDeclaration, enclosingClass) {
    
    shared actual CeylonToJavaMapper mapper;
    abstract => false;
    ceylonToplevelAttribute => false;
    ceylonToplevelMethod => false;
    ceylonToplevelObject => true;

    name => super.name + "_";
    
    shared Type type => decl.type;
    
    declarationForName => decl;
    satisfiedTypes => type.satisfiedTypes;
    supertype => type.extendedType;
    scanExtraMembers(List<MethodMirror> methods)
            => methods.add(GetMethod(this));
    extraInterfaces => [];
}

shared class GetMethod(JObjectMirror obj)
        satisfies MethodMirror {
    abstract => false;
    constructor => false;
    declaredVoid => false;
    default => false;
    defaultAccess => false;
    final => false;
    protected => false;
    public => true;
    static => true;
    staticInit => false;
    variadic => false;
    defaultMethod => false;
    name => NamingBase.Unfix.get_.string;
    parameters => Collections.emptyList<VariableMirror>();
    enclosingClass => obj;
    annotationNames => Collections.emptySet<JString>();
    getAnnotation(String? string) => null;
    returnType => obj.mapper.mapType(obj);
    typeParameters => Collections.emptyList<TypeParameterMirror>();
}

shared String javaQualifiedName(Declaration decl)
        => let (fqn = getJavaNameOfDeclaration(decl))
        if (decl is FunctionOrValue && decl.toplevel,
            exists loc = fqn.lastOccurrence('.'))
        then fqn.initial(loc) //strip off the static method/getter name
        else fqn;

String getJavaNameOfDeclaration(Declaration decl) {
    try {
        return CodegenUtil.getJavaNameOfDeclaration(decl);
    } catch (IllegalArgumentException e) {
        variable value s = decl.scope;
        while (!s is Package) {
            if (!s is TypeDeclaration) {
                platformUtils.log(Status._WARNING, "getJavaNameOfDeclaration: unexpected scope of type ``className(s)``");
                break;
            }
            s = s.container;
        }

        return decl.name;
    }
}