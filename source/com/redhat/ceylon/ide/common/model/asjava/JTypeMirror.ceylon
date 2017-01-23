import com.redhat.ceylon.compiler.java.codegen {
    Naming
}
import com.redhat.ceylon.model.loader.mirror {
    TypeMirror,
    TypeKind,
    ClassMirror,
    TypeParameterMirror
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter,
    Declaration
}

import java.util {
    List,
    Collections,
    Arrays
}

class PrimitiveMirror
        satisfies TypeMirror {
    TypeKind kind_;
    String name;
    
    new create(TypeKind kind, String name) {
        this.kind_ = kind;
        this.name = name;
    }
    
    shared new long extends create(TypeKind.long, "long") {}
    shared new double extends create(TypeKind.double, "double") {}
    shared new float extends create(TypeKind.float, "float") {}
    shared new boolean extends create(TypeKind.boolean, "boolean") {}
    shared new int extends create(TypeKind.int, "int") {}
    shared new short extends create(TypeKind.short, "short") {}
    shared new byte extends create(TypeKind.byte, "byte") {}
    shared new char extends create(TypeKind.char, "char") {}
    shared new \ivoid extends create(TypeKind.\ivoid, "void") {}
    
    componentType => null;
    declaredClass => null;
    kind => kind_;
    lowerBound => null;
    primitive => true;
    qualifiedName => name;
    qualifyingType => null;
    raw => false;
    typeArguments => Collections.emptyList<TypeMirror>();
    typeParameter => null;
    upperBound => null;
    string => name;
}

shared class JTypeMirror 
        satisfies TypeMirror &
        ModelBasedMirror {

    shared actual CeylonToJavaMapper mapper;
    ClassMirror? declaredClass_;
    TypeMirror? componentType_;
    TypeKind kind_;
    TypeMirror? upperBound_;
    TypeMirror? lowerBound_;
    String? qualifiedName_;
    List<TypeMirror> typeArguments_;
    TypeMirror? qualifyingType_;
    variable Boolean? raw_ = null;
    Boolean calculateRaw();
    TypeParameterMirror? typeParameter_;
    
    abstract new wildcard(CeylonToJavaMapper mapper) {
        kind_ = TypeKind.wildcard;
        qualifiedName_ = null;
        qualifyingType_ = null;
        componentType_ = null;
        declaredClass_ = null;
        typeArguments_ = Collections.emptyList<TypeMirror>();        
        calculateRaw = () => false;
        typeParameter_ = null;
        this.mapper = mapper;
    }
    
    shared new extendsWildcard(TypeMirror? upperBound, CeylonToJavaMapper mapper) extends wildcard(mapper) {
        upperBound_ = upperBound;
        lowerBound_ = null;
    }
    shared new superWildcard(TypeMirror? lowerBound, CeylonToJavaMapper mapper) extends wildcard(mapper) {
        upperBound_ = null;
        lowerBound_ = lowerBound;
    }
    shared new unboundWildcard(CeylonToJavaMapper mapper) extends wildcard(mapper) {
        upperBound_ = null;
        lowerBound_ = null;
    }

    shared new apply(TypeMirror klass, {TypeMirror*} typeArguments, CeylonToJavaMapper mapper) {
        assert(exists theDeclaredClass = klass.declaredClass);
        declaredClass_ = theDeclaredClass;
        qualifiedName_ = theDeclaredClass.qualifiedName;
        kind_ = TypeKind.declared;
        typeArguments_ = if(typeArguments.empty)
        then Collections.emptyList<TypeMirror>()
        else Arrays.asList(for (arg in typeArguments) arg);
        qualifyingType_ = klass.qualifyingType;
        calculateRaw = () => false;
        
        upperBound_ = null;
        lowerBound_ = null;
        componentType_ = null;
        typeParameter_ = null;
        
        this.mapper = mapper;
    }
    
    shared new array(TypeMirror componentType, CeylonToJavaMapper mapper) {
        componentType_ = componentType;
        kind_ = TypeKind.array;
        typeArguments_ = Collections.emptyList<TypeMirror>();
        qualifyingType_ = null;
        calculateRaw = let(isRaw = componentType.raw) (() => isRaw);
        qualifiedName_ = null;
        upperBound_ = null;
        lowerBound_ = null;
        declaredClass_ = null;
        typeParameter_ = null;
        
        this.mapper = mapper;
    }

    shared new fromClassMirror(ClassMirror theDeclaredClass, TypeMirror? qualifyingType, CeylonToJavaMapper mapper) {
        declaredClass_ = theDeclaredClass;
        qualifiedName_ = theDeclaredClass.qualifiedName;
        kind_ = TypeKind.declared;
        typeArguments_ = Collections.emptyList<TypeMirror>();
        qualifyingType_ = if (exists qualifyingType) then qualifyingType
        else if (exists enclosingClass = theDeclaredClass.enclosingClass) then mapper.mapType(enclosingClass)
        else null;
        
        calculateRaw = () => ! theDeclaredClass.typeParameters.empty;
        
        upperBound_ = null;
        lowerBound_ = null;
        componentType_ = null;
        typeParameter_ = null;
        
        this.mapper = mapper;
    }

    shared new fromTypeParameter(TypeParameter typeParameter, CeylonToJavaMapper mapper) {
        qualifiedName_ = Naming.quoteIfJavaKeyword(typeParameter.name);
        kind_ = TypeKind.typevar;
        
        if (is Declaration container = typeParameter.container,
            is GenericMirror<out Anything> mirror = mapper.mapDeclaration(container)[0]) {
            value tpMirror = mirror.toTypeParamterMirror(typeParameter);
            typeParameter_ = tpMirror;
        } else {
            typeParameter_ = null;
        }
        
        componentType_ = null;
        declaredClass_ = null;
        qualifyingType_ = null;
        typeArguments_ = Collections.emptyList<TypeMirror>();
        calculateRaw = () => false;
        upperBound_ = null;
        lowerBound_ = null;
        
        this.mapper = mapper;
    }
    
    componentType => componentType_;
    kind => kind_;
    
    declaredClass
            => declaredClass_;
    
    primitive => false;
    
    qualifiedName => qualifiedName_;
    
    qualifyingType => qualifyingType_;
    
    raw => raw_ else (raw_ = calculateRaw());
    
    typeArguments => typeArguments_;
    
    typeParameter => typeParameter_;
    
    upperBound => upperBound_;
    lowerBound => lowerBound_;
    
    shared actual String string {
        switch(theKind = kind)
        case(is Null) {
            return "<unresolved>";
        }
        case(TypeKind.declared | TypeKind.typevar) {
            return "``qualifiedName``<`` ",".join {
                for (ta in typeArguments) ta.string
            } ``>";
        }
        case(TypeKind.wildcard) {
            return "[lower bound]`` lowerBound?.string else "<null>" `` - [upper bound]`` upperBound?.string else "<null>"``";
        }
        case(TypeKind.array) {
            return "``componentType.string``[]";
        }
        case(TypeKind.null) {
            return "'null'";
        }
        case(TypeKind.\ivoid) {
            return "'void'";
        }
        case(TypeKind.error) {
            return "'error'";
        }
        else {
            if (kind.primitive) {
                return kind.name().lowercased;
            }
            else {
                return "'unknown'";
            }
        }
    }
}
