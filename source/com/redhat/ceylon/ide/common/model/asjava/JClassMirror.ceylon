import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.java.codegen {
    ClassTransformer,
    Strategy
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}
import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    TypeParameterMirror,
    FieldMirror,
    TypeMirror,
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    ClassOrInterface,
    Interface,
    Declaration,
    Type,
    Class,
    Constructor,
    FunctionOrValue,
    ClassAlias,
    TypeParameter
}

import java.util {
    List,
    Collections,
    ArrayList,
    Arrays
}

object undefinedMirrorMember {}
alias UndefinedMirrorMember => \IundefinedMirrorMember;

shared abstract class AbstractClassMirror<DeclarationType>
        extends DeclarationMirror<DeclarationType>
        satisfies ClassMirror
        given DeclarationType satisfies Declaration {
    DeclarationType decl;
    variable ClassMirror?|UndefinedMirrorMember enclosingClass_;
    variable TypeMirror?|UndefinedMirrorMember superClass_ = undefinedMirrorMember;
    variable List<TypeMirror>? interfaces_ = null;
    
    shared new (DeclarationType decl, ClassMirror? enclosingClass)
            extends DeclarationMirror<DeclarationType>(decl) {
        this.decl = decl;
        enclosingClass_ = enclosingClass else undefinedMirrorMember;
    }
    
    shared formal Declaration declarationForName;

    variable String? qualifiedName_ = null;
    variable String? flatName_ = null;
    
    value className = let(ceylonFQN = decl.qualifiedNameString)
            if (exists packageSep = ceylonFQN.firstInclusion("::"))
            then "``ceylonFQN[packageSep + 2...]``"
            else ceylonFQN;
                                                                              
    variable Boolean initialized = false;
    variable JPackageMirror? pkgMirror_ = null;
    List<FieldMirror> fields = Collections.emptyList<FieldMirror>();
    
    late List<MethodMirror> methods;
    late List<ClassMirror> innerClasses;

    qualifiedName => qualifiedName_ else (qualifiedName_ = javaQualifiedName(declarationForName));
    flatName => flatName_ else (flatName_ = qualifiedName.replaceLast(className, className.replace(".", "$")));
    
    
    \ipackage => pkgMirror_ else (pkgMirror_=JPackageMirror(declaration.unit.\ipackage));
    
    annotationType => declaration.annotation;
    
    anonymous => name.empty;
    
    defaultAccess => !declaration.shared;
    
    shared actual List<FieldMirror> directFields {
        return fields;
    }
    
    shared actual List<ClassMirror> directInnerClasses {
        scanMembers();
        return innerClasses;
    }
    
    shared actual List<MethodMirror> directMethods {
        scanMembers();
        return methods;
    }
    
    function getEnclosingClassFromDeclaration() => if(is ClassOrInterface container = declaration.container) 
    then JClassMirror(container, null, mapper)
    else null;
    
    enclosingClass => switch(ec = enclosingClass_)
    case(is ClassMirror) ec
    case(is Null) ec
    case(undefinedMirrorMember) (enclosingClass_ = getEnclosingClassFromDeclaration());
    
    enclosingMethod => null;
    
    enum => declaration.javaEnum;
    
    final => if (is ClassOrInterface d = declaration) then d.final else true;
    
    getCacheKey(Module mod) => AbstractModelLoader.getCacheKeyByModule(mod, qualifiedName);
    
    innerClass => declaration.member && !declaration.interfaceMember;
    
    \iinterface => declaration is Interface;
    
    shared {TypeMirror*} satisfiedTypesMirrors => { 
        for (st in satisfiedTypes) 
        if (exists tm = mapper.transformer.prepareJavaType(st, ClassTransformer.jtSatisfies, mapper.javaTreeCreator))
        tm
    };

    shared formal {TypeMirror*} extraInterfaces;
    
    interfaces => interfaces_ else
    (interfaces_ = Arrays.asList(*satisfiedTypesMirrors.chain(extraInterfaces)));

    javaSource => false;
    
    loadedFromSource => false;
    
    localClass => false;
    
    shared actual default String name => declaration.name;
    
    protected => false;
    
    public => declaration.shared;
    
    static => false;
    
    superclass 
            => switch(sc = superClass_)
    case(is TypeMirror) sc
    case(is Null) sc
    case(undefinedMirrorMember) (superClass_ = (! declaration is Interface) then (
                    if (exists s = supertype)
                    then mapper.transformer.prepareJavaType(s, ClassTransformer.jtExtends, mapper.javaTreeCreator)
                    else mapper.javaObjectTypeMirror));
            
            
    
    shared actual default List<TypeParameterMirror> typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    void scanMembers() {
        synchronize(this, () {
            if (initialized) {
                return;
            }
            
            value constructorNames = { 
                for (m in declaration.members)
                    if (is Constructor m) m 
            }.collect<String?>((m) => m.name else "");
            
            function isConstructorFunctionOrValue(Declaration d)
                    => if (is FunctionOrValue d, (d.name else "") in constructorNames)
                    then true
                    else false;
                    
            value members = { 
                for (m in declaration.members)
                    if (! isConstructorFunctionOrValue(m)) 
                        for (d in mapper.mapNonLazyDeclaration(m, this))d
            };
            
            innerClasses = ArrayList<ClassMirror>();
            methods = ArrayList<MethodMirror>();

            members.each((e) {
                if (is MethodMirror e) {
                    methods.add(e); 
                } else {
                    innerClasses.add(e);
                }
            });
            
            scanExtraMembers(methods);
            
            initialized = true;            
        });
    }
    
    shared default void scanExtraMembers(List<MethodMirror> methods)
            => noop();
    
    shared formal Type? supertype;
    shared formal List<Type> satisfiedTypes;
}

shared class JClassMirror(ClassOrInterface decl, ClassMirror? enclosingClass, mapper)
        extends AbstractClassMirror<ClassOrInterface>(decl, enclosingClass)
        satisfies GenericMirror<ClassOrInterface> {
    
    shared actual CeylonToJavaMapper mapper;
    variable List<TypeParameterMirror>? typeParameters_ = null;
    
    declarationForName => declaration;

    ceylonAnnotations => super.ceylonAnnotations.chain {
        if (exists classAnnotation = CeylonAnnotations.classIfNecessary {
            thisType = declaration.type;
            
            extendedType = if (declaration.nativeHeader)
            then declaration.extendedType.extendedType
            else declaration.extendedType;
            
            hasConstructors = if (is Class classDecl = declaration)
            then classDecl.hasConstructors() || classDecl.hasEnumerated()
            else false;
            
            typeFact = declaration.unit;
        }) classAnnotation.entry
    }.chain {
        if (exists ec = enclosingClass)
            CeylonAnnotations.container(this).entry
    }.chain {
        if (exists membersAnnotation = CeylonAnnotations.membersIfNecessary(decl, mapper))
            membersAnnotation.entry
    };
    
    abstract => declaration.abstract || declaration.formal;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => false;
    
    supertype => let (extended = declaration.extendedType)
    if (extended.declaration is Constructor)
    then extended.qualifyingType
    else extended;
    
    satisfiedTypes => declaration.satisfiedTypes;
    
    typeParameters => typeParameters_
            else (typeParameters_ = buildTypeParameters());
    

    shared actual void scanExtraMembers(List<MethodMirror> methods) {
        super.scanExtraMembers(methods);

        if (is Class cl = declaration,
            exists pl = cl.parameterList) {
            
            methods.add(JClassParameterListMirror(cl, this, pl, mapper));
        }
    }
    
    """Logic extracted from the following code of the ClassTransformer.transform(ClassOrInterface):
       ```
        if (model instanceof Class
                && !(model instanceof ClassAlias)
                && plan instanceof Generate) {
            Class c = (Class)model;
            if (Strategy.introduceJavaIoSerializable(c, typeFact().getJavaIoSerializable())) {
                classBuilder.introduce(make().QualIdent(syms().serializableType.tsym));
                if (Strategy.useSerializationProxy(c)
                        && noValueConstructorErrors((Tree.ClassDefinition)def)) {
                    at(def);
                    addWriteReplace(c, classBuilder);
                }
            }
            serialization(c, classBuilder);
        }
       
       ```
       """
    function shouldAddJavaIoSerializableInterface()
            => if (is Class cls = declaration,
            ! declaration is ClassAlias,
            (Strategy.introduceJavaIoSerializable(cls, mapper.typeFactory.javaIoSerializable) ||
                cls.serializable)) then true else false;
    
    
    shared actual {TypeMirror*} extraInterfaces => concatenate(
        {
            if (shouldAddJavaIoSerializableInterface())
            mapper.javaIoSerializableTypeMirror
        },
        {
            if (declaration is Class && 
                mapper.transformer.shouldAddReifiedTypeInterface(declaration))
            mapper.reifiedTypeTypeMirror
        }
    );
    
    shared actual TypeParameterMirror toTypeParamterMirror(TypeParameter tp)
            => JTypeParameterMirror(tp, (tp) => CeylonIterable(mapper.transformer.prepareTypeParameterBounds(tp.satisfiedTypes, mapper.javaTreeCreator)));    
}