import org.eclipse.ceylon.compiler.java.codegen {
    CodegenUtil
}
import org.eclipse.ceylon.model.loader {
    NamingBase
}
import org.eclipse.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror
}
import org.eclipse.ceylon.model.typechecker.model {
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
import org.eclipse.ceylon.ide.common.platform {
    platformUtils,
    Status
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
    
    scanExtraMembers(List<MethodMirror> methods)
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