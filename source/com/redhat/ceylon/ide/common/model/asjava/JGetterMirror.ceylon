import com.redhat.ceylon.compiler.java.codegen {
    CodegenUtil,
    AbstractTransformer
}
import com.redhat.ceylon.model.loader.mirror {
    TypeParameterMirror,
    VariableMirror,
    ClassMirror,
    TypeMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value
}

import java.util {
    Collections
}

shared class JGetterMirror(Value decl, ClassMirror? enclosingClass, mapper)
        extends AbstractMethodMirror<Value>(decl, enclosingClass) {
    
    shared actual CeylonToJavaMapper mapper;
    variable Integer? flags_ = null;
    
    flags => flags_ else 
    (flags_ = mapper.transformer.modifierTransformation().getterSetter(decl, false));

    String capitalize(String str) {
        return (str.first?.uppercased?.string else "") + str.rest;
    }
    name = switch(name = decl.name)
    case("hash") "hashCode"
    case("string") "toString"
    else "get" + capitalize(decl.name);

    variable TypeMirror? returnType_ = null;
    constructor = false;
    declaredVoid = false;
    parameters = Collections.emptyList<VariableMirror>();
    typeParameters = Collections.emptyList<TypeParameterMirror>();
    variadic = false;
    defaultMethod = false;

    abstract => super.abstract ||
            (if (exists enclosingClass)
        then enclosingClass.\iinterface else false);
    
    
    """
       Logic extracted from `ClassTransformer.transform(AttributeDeclaration decl, ClassDefinitionBuilder classBuilder)`
       """
    TypeMirror buildResultType() {
        variable Integer typeFlags = 0;
        value typedRef = mapper.transformer.getTypedReference(declaration);
        value nonWideningTypedRef = mapper.transformer.nonWideningTypeDecl(typedRef);
        value nonWideningType = mapper.transformer.nonWideningType(typedRef, nonWideningTypedRef);
        if(declaration.actual
            && CodegenUtil.hasTypeErased(declaration)) {
            typeFlags = typeFlags.or(AbstractTransformer.jtRaw);
        }
        if (!CodegenUtil.isUnBoxed(nonWideningTypedRef.declaration)) {
            typeFlags = typeFlags.or(AbstractTransformer.jtNoPrimitives);
        }
        
        return mapper.transformer.prepareJavaType(nonWideningType, typeFlags, mapper.javaTreeCreator);
    }
    returnType => returnType_ else (returnType_ = (name == "hashCode") then PrimitiveMirror.int else buildResultType());
}
