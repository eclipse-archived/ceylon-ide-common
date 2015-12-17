import ceylon.collection {
    HashSet,
    MutableSet,
    naturalOrderTreeMap,
    naturalOrderTreeSet
}
import ceylon.interop.java {
    createJavaObjectArray,
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.compiler.java.loader {
    TypeFactory,
    AnnotationLoader,
    SourceDeclarationVisitor
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    Context
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model.mirror {
    SourceDeclarationHolder,
    SourceClass
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast,
    synchronize,
    equalsWithNulls
}
import com.redhat.ceylon.model.loader {
    TypeParser,
    Timer
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    MethodMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.loader.model {
    LazyPackage,
    LazyValue,
    LazyFunction,
    LazyClass,
    LazyInterface,
    AnnotationProxyMethod,
    AnnotationProxyClass,
    LazyElement
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Modules,
    Unit,
    Package,
    Declaration,
    Class,
    Parameter,
    UnknownType {
        ErrorReporter
    }
}

import java.lang {
    ObjectArray,
    JString=String,
    Runnable,
    RuntimeException
}
import java.util {
    JList=List,
    JArrayList=ArrayList,
    Collections
}

shared abstract class BaseIdeModelLoader(
            BaseIdeModuleManager theModuleManager,
            BaseIdeModuleSourceMapper theModuleSourceMapper,
            Modules theModules
        ) extends AbstractModelLoaderEx(theModuleManager, theModuleSourceMapper.context, theModules) {
    
    value _sourceDeclarations = naturalOrderTreeMap<String, SourceDeclarationHolder> {};
    variable Boolean mustResetLookupEnvironment = false;
    shared MutableSet<String> modulesInClassPath = naturalOrderTreeSet<String> {};
    
    shared late AnnotationLoader annotationLoader;
    shared default BaseIdeModuleSourceMapper moduleSourceMapper = theModuleSourceMapper;
    shared actual default BaseIdeModuleManager moduleManager => 
            unsafeCast<BaseIdeModuleManager>(super.moduleManager);
    
    shared actual void initAnnotationLoader() {
        annotationLoader = AnnotationLoader(this, typeFactory);
    }

    shared actual TypeParser newTypeParser() => TypeParser(this);
    shared actual Unit newTypeFactory(Context context) => GlobalTypeFactory(context);
    shared actual Timer newTimer() => Timer(false);
   
    BaseIdeModelLoader this_ => this;
    shared Map<String, SourceDeclarationHolder> sourceDeclarations => _sourceDeclarations;

    shared class GlobalTypeFactory(Context context) 
           extends TypeFactory(context) {
       
        shared actual Package \ipackage =>
                let (do = () {
                    if(! super.\ipackage exists){
                        super.\ipackage = modules.languageModule
                            .getDirectPackage(Module.\iLANGUAGE_MODULE_NAME);
                    }
                    return super.\ipackage;
                }) synchronize(this_, do); 
            
       assign \ipackage {
           super.\ipackage = \ipackage;
       }
   }
   
   shared class PackageTypeFactory(Package pkg) 
           extends PackageTypeFactoryBase(pkg, moduleSourceMapper.context) {
   }
   
   shared TypeFactory newPackageTypeFactory(Package pkg) =>
           PackageTypeFactory(pkg);
   
   
   shared void resetJavaModelSourceIfNecessary(Runnable resetAction) {
       synchronize {
           on = this;
           void do() {
               if (mustResetLookupEnvironment) {
                   resetAction.run();
                   mustResetLookupEnvironment = false;
               }
           }
       };
   }
   
   "
    TODO : remove when the bug in the AbstractModelLoader is corrected
    "
   shared actual LazyPackage findOrCreatePackage(Module? mod, String pkgName) =>
       let(do = () {
           value pkg = super.findOrCreatePackage(mod, pkgName);
           value currentModule = pkg.\imodule;
           if (currentModule.java){
               pkg.shared = true;
           }
           if (currentModule == modules.defaultModule 
               && !equalsWithNulls(currentModule,mod)) {
               currentModule.packages.remove(pkg);
               pkg.\imodule = null;
               if (exists mod) {
                   mod.packages.add(pkg);
                   pkg.\imodule = mod;
               }
           }
           return pkg;
       }) synchronize(this, do);
       
   shared actual Module loadLanguageModuleAndPackage() {
       value lm = languageModule;
       if (moduleManager.loadDependenciesFromModelLoaderFirst
           && !isBootstrap) {
           findOrCreatePackage(lm, \iCEYLON_LANGUAGE);
       }
       return lm;
   }
   
   shared actual ObjectArray<ClassMirror> getClassMirrorsToRemove(Declaration declaration) {
       ObjectArray<ClassMirror> mirrors = super.getClassMirrorsToRemove(declaration);
       if (mirrors.size == 0) {
           Unit? unit = declaration.unit;
           if (is SourceFile unit) {
               String fqn = getToplevelQualifiedName(unit.ceylonPackage.nameAsString, declaration.nameAsString);
               SourceDeclarationHolder? holder = _sourceDeclarations.get(fqn);
               if (exists holder) {
                   return createJavaObjectArray { SourceClass(holder) };
               }
           }
       }
       return mirrors;
   }
   
   shared actual void removeDeclarations(JList<Declaration> declarations) {
       void do() {
           JList<Declaration> allDeclarations = JArrayList<Declaration>(declarations.size());
           MutableSet<Package> changedPackages = HashSet<Package>();
           
           allDeclarations.addAll(declarations);
           
           for (declaration in CeylonIterable(declarations)) {
               Unit? unit = declaration.unit;
               if (exists unit) {
                   changedPackages.add(unit.\ipackage);
               }
               retrieveInnerDeclarations(declaration, allDeclarations);
           }
           for (decl in CeylonIterable(allDeclarations)) {
               String fqn = getToplevelQualifiedName(decl.container.qualifiedNameString, decl.name);
               _sourceDeclarations.remove(fqn);
           }
           
           super.removeDeclarations(allDeclarations);
           for (changedPackage in changedPackages) {
               loadedPackages.remove(javaString(cacheKeyByModule(changedPackage.\imodule, changedPackage.nameAsString)));
           }
           mustResetLookupEnvironment = true;
       }
       synchronize(lock, do);
   }
   
   void retrieveInnerDeclarations(Declaration declaration,
       JList<Declaration> allDeclarations) {
       variable JList<Declaration> members;
       try {
           members = declaration.members;
       } catch(Exception e) {
           members = Collections.emptyList<Declaration>();
       }
       allDeclarations.addAll(members);
       for (member in CeylonIterable(members)) {
           retrieveInnerDeclarations(member, allDeclarations);
       }
   }
   
   shared void clearCachesOnPackage(String packageName) {
       void do() {
           JList<JString> keysToRemove = JArrayList<JString>(classMirrorCache.size());
           for (element in CeylonIterable(classMirrorCache.entrySet())) {
               if (! element.\ivalue exists) {
                   JString? className = element.key;
                   if (exists className) {
                       String classPackageName = className.replaceAll("\\.[^\\.]+$", "");
                       if (classPackageName.equals(packageName)) {
                           keysToRemove.add(className);
                       }
                   }
               }
           }
           for (keyToRemove in CeylonIterable(keysToRemove)) {
               classMirrorCache.remove(keyToRemove);
           }
           Package pkg = findPackage(packageName);
           loadedPackages.remove(javaString(cacheKeyByModule(pkg.\imodule, packageName)));
           mustResetLookupEnvironment = true;
       }
       synchronize(lock, do);
   }
   
   shared void clearClassMirrorCacheForClass(BaseIdeModule mod, String classNameToRemove) {
       synchronize(lock, () {
           classMirrorCache.remove(cacheKeyByModule(mod, classNameToRemove));        
           mustResetLookupEnvironment = true;
       });
   }
   
   shared actual void setupSourceFileObjects(JList<out Object> treeHolders) {
       synchronize (lock, () {
           addSourcePhasedUnits(treeHolders, true);
       });
   }
   
    shared void addSourcePhasedUnits(JList<out Object> treeHolders, Boolean isSourceToCompile) {
       synchronize (lock, () {
           for (Object treeHolder in CeylonIterable(treeHolders)) {
               if (is PhasedUnit treeHolder) {
                   value pkgName = treeHolder.\ipackage.qualifiedNameString;
                   treeHolder.compilationUnit.visit(object extends SourceDeclarationVisitor(){
                       shared actual void loadFromSource(Tree.Declaration decl) {
                           if (exists id=decl.identifier) {
                               String fqn = getToplevelQualifiedName(pkgName, id.text);
                               if (! _sourceDeclarations.defines(fqn)) {
                                   _sourceDeclarations.put(fqn, SourceDeclarationHolder(treeHolder, decl, isSourceToCompile));
                               }
                           }
                       }
                       shared actual void loadFromSource(Tree.ModuleDescriptor that) {
                       }
                       
                       shared actual void loadFromSource(Tree.PackageDescriptor that) {
                       }
                   });
               }
           }
       });
    }
   
    shared void addSourceArchivePhasedUnits(JList<PhasedUnit> sourceArchivePhasedUnits) =>
            addSourcePhasedUnits(sourceArchivePhasedUnits, false);
   
    shared actual LazyValue makeToplevelAttribute(ClassMirror classMirror, Boolean isNativeHeader) => 
            if (is SourceClass classMirror) 
            then unsafeCast<LazyValue>(classMirror.modelDeclaration) 
            else super.makeToplevelAttribute(classMirror, isNativeHeader);
   
    shared actual LazyFunction makeToplevelMethod(ClassMirror classMirror, Boolean isNativeHeader) => 
            if (is SourceClass classMirror) 
            then unsafeCast<LazyFunction>(classMirror.modelDeclaration) 
            else super.makeToplevelMethod(classMirror, isNativeHeader);
   
    shared actual LazyClass makeLazyClass(ClassMirror classMirror, Class superClass,
               MethodMirror constructor, Boolean isNativeHeader) => 
            if (is SourceClass classMirror) 
            then unsafeCast<LazyClass>(classMirror.modelDeclaration) 
            else super.makeLazyClass(classMirror, superClass, constructor, isNativeHeader);
   
    shared actual LazyInterface makeLazyInterface(ClassMirror classMirror, Boolean isNativeHeader) => 
            if (is SourceClass classMirror) 
            then unsafeCast<LazyInterface>(classMirror.modelDeclaration) 
            else super.makeLazyInterface(classMirror, isNativeHeader);
   
    shared actual Module findModuleForClassMirror(ClassMirror classMirror) => 
            lookupModuleByPackageName(
               getPackageNameForQualifiedClassName(classMirror));
   
    shared actual void loadJDKModules() =>
            super.loadJDKModules();
   
    shared actual LazyPackage findOrCreateModulelessPackage(String pkgName) =>
            synchronize(lock, () => unsafeCast<LazyPackage>(findPackage(pkgName)));
   
    shared actual Boolean isModuleInClassPath(Module mod) {
       if (modulesInClassPath.contains(mod.signature)) {
           return true;
       }
       if (is BaseIdeModule mod, mod.isProjectModule) {
           return true;
       }
       if (is BaseIdeModule mod, 
           exists origMod = mod.originalModule,  
           origMod.isProjectModule) {
           return true;
       }
       return false;
   }
   
   shared actual Boolean needsLocalDeclarations() => false;
   
   shared void addJDKModuleToClassPath(Module mod) =>
           modulesInClassPath.add(mod.signature);
   
    shared actual Boolean autoExportMavenDependencies =>
            moduleManager.ceylonProject
                ?.configuration?.autoExportMavenDependencies
                    else false;
      
    shared actual Boolean flatClasspath =>
            moduleManager.ceylonProject
                ?.configuration?.flatClasspath
                    else false;

    shared actual void makeInteropAnnotationConstructorInvocation(AnnotationProxyMethod arg0, AnnotationProxyClass arg1, JList<Parameter> arg2) =>
            annotationLoader.makeInterorAnnotationConstructorInvocation(arg0, arg1, arg2);
   
   shared actual ErrorReporter makeModelErrorReporter(Module mod, String msg) =>
           object extends ErrorReporter(msg) {
               reportError() =>
                    moduleSourceMapper.attachErrorToOriginalModuleImport(mod, message);
           };
   
   shared actual void setAnnotationConstructor(LazyFunction arg0, MethodMirror arg1) {
       annotationLoader.setAnnotationConstructor(arg0, arg1);
   }
   
   shared String? getNativeFromMirror(ClassMirror classMirror) {
       if (is SourceClass classMirror) {
           return getNative(classMirror.astDeclaration);
       }
       
       AnnotationMirror? annotation = classMirror.getAnnotation("ceylon.language.NativeAnnotation$annotation$");
       if (! exists annotation) {
           return null;
       }
       Object? backend = annotation.getValue("backend");
       if (! exists backend) {
           return "";
       }
       if (is JString backend) {
           return backend.string;
       }
       return null;
   }
   
   shared String? getNative(Tree.Declaration decl) {
       for (Tree.Annotation annotation in CeylonIterable(decl.annotationList.annotations)) {
           String? text = annotation.primary.token.text;
           if (exists text, text == "native") {
               variable String backend = "";
               if (exists pal = annotation.positionalArgumentList,
                    exists pas = pal.positionalArguments,
                    !pas.empty) {
                   variable String argText = pas.get(0).endToken.text;
                   if (equalsWithNulls(argText.first, '"')) {
                       argText = argText.rest;
                   }
                   if (equalsWithNulls(argText.last, '"')) {
                       argText = argText.initial(argText.size-1);
                   }
                   backend = argText;
               }
               return backend;
           }
       }
       return null;
   }
   
   
   shared formal Boolean moduleContainsClass(BaseIdeModule ideModule, String packageName, String className);
   
   shared actual Boolean forceLoadFromBinaries(Boolean isNativeDeclaration) =>
           moduleManager.loadDependenciesFromModelLoaderFirst 
               && isNativeDeclaration;
   
   shared actual Boolean forceLoadFromBinaries(Tree.Declaration declarationNode) =>
           forceLoadFromBinaries(getNative(declarationNode) exists);
   
   shared actual Boolean forceLoadFromBinaries(Declaration declaration) {
       return forceLoadFromBinaries(declaration.native);
   }
   
   shared actual Boolean forceLoadFromBinaries(ClassMirror classMirror) {
       return forceLoadFromBinaries(getNativeFromMirror(classMirror) exists);
   }
   
   shared actual Boolean searchAgain(ClassMirror? cachedMirror, Module ideModule, String name) {
       if (cachedMirror exists 
           && ( !(cachedMirror is SourceClass) || 
                   !forceLoadFromBinaries(cachedMirror))) {
           return false;
       }
       if (is BaseIdeModule ideModule) {
           JString nameJString = javaString(name);
           if (ideModule.isCeylonBinaryArchive || ideModule.isJavaBinaryArchive) {
               String classRelativePath = nameJString.replace('.', '/');
               return ideModule.containsClass(classRelativePath + ".class") || ideModule.containsClass(classRelativePath + "_.class");
           } else if (ideModule.isProjectModule) {
               value nameLength = nameJString.length();
               value packageEnd = nameJString.lastIndexOf('.'.integer);
               value classNameStart = packageEnd + 1;
               String packageName = if (packageEnd > 0) then nameJString.substring(0, packageEnd) else "";
               String className = if (classNameStart < nameLength) then nameJString.substring(classNameStart) else "";
               return moduleContainsClass(ideModule, packageName, className);
           }
       }
       return false;
   }
   
   shared actual Boolean searchAgain(Declaration? cachedDeclaration, LazyPackage lazyPackage, String name) {
       if (cachedDeclaration exists && 
           (cachedDeclaration is LazyElement || 
           !forceLoadFromBinaries(cachedDeclaration))) {
           return false;
       }
       return searchAgain(null, lazyPackage.\imodule, lazyPackage.getQualifiedName(lazyPackage.qualifiedNameString, name));
   }

   shared actual Declaration? convertToDeclaration(Module ideModule, String typeName,
       DeclarationType declarationType) {
        return let (do = () {
           value fqn = getToplevelQualifiedName(typeName);
           
           SourceDeclarationHolder? foundSourceDeclaration = sourceDeclarations.get(fqn);
           if (exists foundSourceDeclaration,
               ! forceLoadFromBinaries(foundSourceDeclaration.astDeclaration)) {
               return foundSourceDeclaration.modelDeclaration;
           }
           
           variable Declaration? result = null;
           try {
               result = super.convertToDeclaration(ideModule, typeName, declarationType);
           } catch(RuntimeException e) {
               // FIXME: pretty sure this is plain wrong as it ignores problems and especially ModelResolutionException and just plain hides them
           }
           if (exists foundSourceDeclaration, 
               ! (result exists)) {
               result = foundSourceDeclaration.modelDeclaration;
           }
           return result;
       }) synchronize (lock, do);
   }
   

}

shared abstract class IdeModelLoader<NativeProject, NativeResource, NativeFolder, NativeFile> extends BaseIdeModelLoader {
    shared new (
        IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> moduleManager,
        IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile> moduleSourceMapper,
        Modules modules
    ) extends BaseIdeModelLoader(moduleManager, moduleSourceMapper, modules){
    }
    
    shared actual IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> moduleManager => 
            unsafeCast<IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.moduleManager);
    
    shared actual IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile> moduleSourceMapper => 
            unsafeCast<IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.moduleSourceMapper);

}