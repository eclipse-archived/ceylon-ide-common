import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.java.codegen {
    ClassTransformer,
    AbstractTransformer,
    Naming {
        TypeDeclarationBuilder
    }
}
import com.redhat.ceylon.compiler.java.loader {
    TypeFactory
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject,
    unknownTypeMirror
}
import com.redhat.ceylon.ide.common.model.mirror {
    SourceClass
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.langtools.tools.javac.code {
    BoundKind
}
import com.redhat.ceylon.langtools.tools.javac.util {
    List
}
import com.redhat.ceylon.model.loader.mirror {
    TypeMirror,
    ClassMirror,
    MethodMirror
}
import com.redhat.ceylon.model.loader.model {
    LazyClass,
    LazyInterface,
    LazyFunction,
    LazyElement,
    LazyClassAlias,
    LazyInterfaceAlias,
    LazyTypeAlias,
    LazyValue
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Value,
    Function,
    Type,
    ClassOrInterface,
    Class,
    TypeParameter,
    Setter,
    Constructor,
    Interface,
    TypeDeclaration,
    Module
}

shared class CeylonToJavaMapper(BaseCeylonProject ceylonProject, PhasedUnit?(Declaration) toSource) {

    assert(exists modelLoader = ceylonProject.modelLoader);
    
    shared TypeFactory typeFactory = modelLoader.typeFactory;
    
    
    shared Class javaStringDeclaration = typeFactory.javaStringDeclaration;
    assert(is LazyClass javaStringDeclaration);
    
    assert(exists theJavaObjectTypeMirror = javaStringDeclaration.classMirror.superclass);
    assert(exists javaModule = javaStringDeclaration.unit?.\ipackage?.\imodule);
    
    shared TypeMirror javaObjectTypeMirror = theJavaObjectTypeMirror;
    
    assert(exists javaObjectClassMirror = javaObjectTypeMirror.declaredClass);
    assert(exists theJavaStringTypeMirror = CeylonIterable(javaObjectClassMirror.directMethods)
            .find((m) => m.name == "toString")?.returnType);

    assert(is LazyClass basicDeclaration = typeFactory.basicDeclaration);
    assert(exists languageModule = basicDeclaration.unit?.\ipackage?.\imodule);
    assert(exists basicClassMirror = basicDeclaration.classMirror);
    assert(exists theReifiedTypeTypeMirror = basicClassMirror.interfaces.get(0));
    assert(exists theTypeDescriptorTypeMirror = theReifiedTypeTypeMirror.declaredClass.directMethods.get(0).returnType);
    assert(exists theJavaIoSerializableTypeMirror = basicClassMirror.interfaces.get(1));
    assert(exists typeChecker = ceylonProject.typechecker);
    assert(exists javaAnnotationDeclaration = typeFactory.annotationDeclaration);
    assert(exists ceylonExceptionDeclaration = typeFactory.exceptionDeclaration);
        
        
    shared TypeMirror javaStringTypeMirror = theJavaStringTypeMirror;
    shared TypeMirror reifiedTypeTypeMirror = theReifiedTypeTypeMirror;
    shared TypeMirror javaIoSerializableTypeMirror = theJavaIoSerializableTypeMirror;

    shared Tree.Declaration? declarationToNode(Declaration d) {
        if (exists ast = toSource(d)?.compilationUnit) {
            value node = nodes.findReferencedNode(ast, d);
            assert(is Tree.Declaration? node);
            return node;
        }
        return null;
    }

    assert(exists javacContext = ceylonProject.createJavacContextWithClassTransformer());
    
    shared ClassTransformer transformer = ClassTransformer.getInstance(javacContext);
    shared Naming naming = Naming.instance(javacContext);
    
    class MirrorDeclarationBuilder(Declaration decl, TypeMirror qualifying) extends TypeDeclarationBuilder<TypeMirror>(decl) {
        variable TypeMirror expr = qualifying;
        
        shared actual void select(String s) {
            for (dic in expr.declaredClass.directInnerClasses) {
                if (dic.name == s) {
                    expr = mapType([dic, expr]);
                    break;
                }
            } else {
                assert(false);
            }
        }
        
        result() => expr;
        
        shared actual void clear() {
            super.clear();
            expr = qualifying;
        }
    }
    
    shared object javaTreeCreator 
            satisfies AbstractTransformer.AnnotationCreator<CeylonAnnotations> &
            AbstractTransformer.TypeCreator<TypeMirror> {
        // Annotations
        
        createTypeInfoAnnotation(String type, Boolean erased, Boolean declaredVoid, Boolean untrusted, Boolean uncheckedNull)
            => CeylonAnnotations.typeInfo(type, erased, declaredVoid, untrusted, uncheckedNull);
        
        createMembersAnnotation(List<Object> memberTypes)
            => (! memberTypes.empty) then CeylonAnnotations.members {
                for(mt in memberTypes) 
                    if(is String|Type mt) 
                        let(typeInfo = switch(mt)
                            case(is String) mt
                            case(is Type) transformer.prepareClassLiteral(mt, 0, this))
                        CeylonAnnotations.member(typeInfo,outer).annotation
            };
        
        // Types
            
        floatTypeIdent() => PrimitiveMirror.float;
        doubleTypeIdent() => PrimitiveMirror.double;
        shortTypeIdent() => PrimitiveMirror.short;
        intTypeIdent() => PrimitiveMirror.int;
        longTypeIdent() => PrimitiveMirror.long;
        charTypeIdent() => PrimitiveMirror.char;
        byteTypeIdent() => PrimitiveMirror.byte;
        booleanTypeIdent() => PrimitiveMirror.boolean;
        voidTypeIdent() => PrimitiveMirror.\ivoid;
        voidType() => PrimitiveMirror.\ivoid;
        objectType() => javaObjectTypeMirror;
        stringType() => javaStringTypeMirror;
        typeDescriptorTypeIdent() => theTypeDescriptorTypeMirror;

        
        TypeMirror fromLazyTypeDeclaration(TypeDeclaration decl) {
            if (is LazyClass decl) {
                return JTypeMirror.fromClassMirror(decl.classMirror, null, outer);
            } else if (is LazyInterface decl) {
                return JTypeMirror.fromClassMirror(decl.classMirror, null, outer);
            } else {
                assert(false);
            }
        }
        
        TypeMirror fromDeclarationName(Module mod, String declarationName) {
            assert(exists mirror = modelLoader.lookupClassMirror(mod, declarationName));
            return outer.mapType(mirror);
        }

        annotationType() => fromLazyTypeDeclaration(javaAnnotationDeclaration);
        ceylonAbstractCallableTypeIdent() => fromDeclarationName(languageModule, "com.redhat.ceylon.compiler.java.language.AbstractCallable");
        ceylonAbstractTypeConstructorTypeIdent() => fromDeclarationName(languageModule, "com.redhat.ceylon.compiler.java.language.AbstractTypeConstructor");
        ceylonExceptionTypeIdent() => fromLazyTypeDeclaration(ceylonExceptionDeclaration);
        exceptionType() => fromDeclarationName(javaModule, "java.lang.Exception");
        throwableType() => fromDeclarationName(javaModule, "java.lang.Throwable");
        throwableTypeIdent() => fromDeclarationName(javaModule, "java.lang.Throwable");

        shared actual TypeMirror erroneous() => unknownTypeMirror;
        shared actual TypeMirror erroneous(String? message) => unknownTypeMirror;
        
        apply(TypeMirror clazz, List<TypeMirror> arguments)
                => JTypeMirror.apply(clazz, CeylonIterable(arguments), outer);
        
        array(TypeMirror elementType)
                => JTypeMirror.array(elementType, outer);
        
        wildcard(BoundKind boundKind, TypeMirror? bound)
                => switch(boundKind)
                case(BoundKind.\iextends) JTypeMirror.extendsWildcard(bound, outer)
                case(BoundKind.\isuper) JTypeMirror.extendsWildcard(bound, outer)
                case(BoundKind.unbound) JTypeMirror.unboundWildcard(outer);

        function getModule(Declaration decl) => let (externalMod = decl.unit.\ipackage.\imodule)
                        modelLoader.findModule(externalMod.nameAsString, externalMod.version);

        companionClassIdent(Interface tdecl)
                => let(mod = getModule(tdecl))
                fromDeclarationName(mod, naming.getCompanionClassName(tdecl, true).trimLeading('.'.equals));
        
        shared actual TypeMirror declarationIdent(TypeDeclaration tdecl, Naming.DeclNameFlag?* flags) {
            value mod = getModule(tdecl);

            if (exists mirror = modelLoader.lookupClassMirror(mod, naming.makeTypeDeclarationName(tdecl, *flags).trimLeading('.'.equals))) {
                return mapType(mirror);
            } else if (exists flag = flags.first,
                flags.rest.empty,
                flag == Naming.DeclNameFlag.qualified) {
                if (is ClassMirror mirror = mapDeclaration(tdecl).first) {
                    return mapType(mirror);
                }
            }
            assert(false);
        }
        
        typeParamemerIdent(TypeParameter tdecl) 
                => JTypeMirror.fromTypeParameter(tdecl, outer);

        shared actual TypeMirror typeDeclarationIdent(TypeMirror qualifyingExpr, TypeDeclaration decl, Naming.DeclNameFlag?* options)  {
            value helper = MirrorDeclarationBuilder(decl, qualifyingExpr); 
            return naming.makeTypeDeclaration(helper, decl, *options);
        }
        
        shared actual TypeMirror underlyingTypeIdent(Type type) {
            String underlyingType = type.underlyingType;    // TODO: incorrect: attention -> pas quoted
            assert(exists pkg = underlyingType.split('.'.equals)
                    .scan("")((previous, last) => !previous.empty then "``previous``.``last``" else last)
                    .map((pkgName) => modelLoader.findPackage(pkgName))
                    .coalesced
                    .last);
            
            return fromDeclarationName(pkg.\imodule, underlyingType);
        }
    }
    
    function mapFunction(Function fun, ClassMirror? enclosingClass = null) {
        if (fun.toplevel) {
            return [JToplevelFunctionMirror(fun, this)];
        } else {
            assert(exists enclosingClass);
            return [JMethodMirror(fun, enclosingClass, this)];
        }
    }

    function mapValue(Value decl, ClassMirror? enclosingClass = null) {
        if (decl.toplevel) { //TODO: can this possibly be correct??! decl.anonymous, no?
            return [JObjectMirror(decl, enclosingClass, this)];
        }
        else{
             if (decl.shared) {
                 return decl.variable
                 then [JGetterMirror(decl, enclosingClass, this), JSetterMirror(decl, enclosingClass, this)]
                 else [JGetterMirror(decl, enclosingClass, this)];
            } else {
                return [];
            }
        }
    }

    suppressWarnings("expressionTypeNothing")
    function mapLazyElement(LazyElement lazyDecl) =>
            [switch(lazyDecl)
    case(is LazyClass) lazyDecl.classMirror
    case(is LazyFunction) lazyDecl.classMirror
    case(is LazyInterface) lazyDecl.classMirror
    case(is LazyClassAlias) lazyDecl.classMirror
    case(is LazyInterfaceAlias) lazyDecl.classMirror
    case(is LazyTypeAlias) lazyDecl.classMirror
    case(is LazyValue) lazyDecl.classMirror
    else nothing];

    shared <ClassMirror|MethodMirror>[] mapNonLazyDeclaration<DeclarationType>(DeclarationType decl, ClassMirror? enclosingClass)
            given DeclarationType satisfies Declaration {
        switch (decl)
        case (is ClassOrInterface) {
            return [JClassMirror(decl, enclosingClass, this)];
        }
        case (is Value) {
            return mapValue(decl, enclosingClass);
        }
        case (is Function) {
            return mapFunction(decl, enclosingClass);
        }
        case (is TypeParameter) {
            return []; // TODO
        }
        case (is Setter) {
            return [];
        }
        case (is Constructor) {
            assert(exists enclosingClass);
            return [JConstructorMirror(decl, enclosingClass, this)];
        }
        else {
            "Unsupported declaration type"
            assert(false);
        }
    }

    shared <ClassMirror|MethodMirror>[] mapDeclaration<DeclarationType>(DeclarationType decl)
        given DeclarationType satisfies Declaration
            => if (is LazyElement decl)
            then mapLazyElement(decl)
            else mapNonLazyDeclaration(decl, null);

    shared TypeMirror mapType(ClassMirror|[ClassMirror, TypeMirror] typeSource) {
            ClassMirror classMirror;
            TypeMirror? qualifyingType;
            if(is ClassMirror typeSource) {
                classMirror = typeSource;
                qualifyingType = null;
            } else {
                value typeSourceMirror = typeSource[0];
                if (is SourceClass typeSourceMirror,
                    is ClassOrInterface sourceModel = typeSourceMirror.modelDeclaration) {
                    classMirror = JClassMirror(sourceModel, null, this);
                } else {
                    classMirror = typeSourceMirror;
                }
                qualifyingType = typeSource[1];
            }            
            return JTypeMirror.fromClassMirror(classMirror, qualifyingType, this);
    }
}