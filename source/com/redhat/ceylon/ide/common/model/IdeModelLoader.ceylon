import ceylon.collection {
    HashSet,
    MutableSet,
    naturalOrderTreeMap,
    naturalOrderTreeSet,
    MutableMap,
    HashMap
}
import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.common {
    JVMModuleUtil
}
import com.redhat.ceylon.compiler.java.loader {
    TypeFactory,
    AnnotationLoader,
    SourceDeclarationVisitor
}
import com.redhat.ceylon.compiler.java.util {
    Util
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
    SourceClass,
    IdeClassMirror
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status,
    JavaModelServicesConsumer
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast,
    equalsWithNulls
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult
}
import com.redhat.ceylon.model.loader {
    TypeParser,
    Timer,
    NamingBase
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
    LazyElement,
    LazyModule
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
    shared MutableMap<String,Boolean> packageExistence = HashMap<String, Boolean>();
    
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
   
    shared Map<String, SourceDeclarationHolder> sourceDeclarations => _sourceDeclarations;

    shared void runWithLock(void action()) => synchronizedRun(action);

    shared T callWithLock<T>(T fun()) => synchronizedCall(() => fun() else null);
    
    shared class GlobalTypeFactory(Context context) 
           extends TypeFactory(context) {
       
    shared actual Package \ipackage
            => let (do = () {
                if (!super.\ipackage exists) {
                    super.\ipackage = modules.languageModule
                        .getDirectPackage(Module.languageModuleName);
                }
                return super.\ipackage;
            })
            callWithLock(do);
            
       assign \ipackage {
           super.\ipackage = \ipackage;
       }
   }
   
   shared class PackageTypeFactory(Package pkg) 
           extends PackageTypeFactoryBase(pkg, moduleSourceMapper.context) {
   }
   
   shared TypeFactory newPackageTypeFactory(Package pkg) =>
           PackageTypeFactory(pkg);
   
   
   shared void resetJavaModelSourceIfNecessary(void resetAction()) {
       callWithLock(() {
           if (mustResetLookupEnvironment) {
               resetAction();
               mustResetLookupEnvironment = false;
           }
       });
   }
   
   "
    TODO : remove when the bug in the AbstractModelLoader is corrected
    "
   shared actual LazyPackage findOrCreatePackage(Module? mod, String pkgName) =>
       let (do = () {
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
       })
       callWithLock(do);
       
   shared actual Module loadLanguageModuleAndPackage() {
       value lm = languageModule;
       if (moduleManager.loadDependenciesFromModelLoaderFirst
           && !isBootstrap) {
           findOrCreatePackage(lm, ceylonLanguage);
       }
       return lm;
   }
   
   shared actual ObjectArray<ClassMirror> getClassMirrorsToRemove(Declaration declaration) {
       value mirrors = super.getClassMirrorsToRemove(declaration);
       if (mirrors.size == 0,
           is SourceFile unit = declaration.unit) {
           String fqn = getToplevelQualifiedName(unit.ceylonPackage.nameAsString, declaration.nameAsString);
           if (exists holder = _sourceDeclarations.get(fqn)) {
               return ObjectArray.with { SourceClass(holder) };
           }
       }
       return mirrors;
   }
   
   shared actual void removeDeclarations(JList<Declaration> declarations) {
       void do() {
           value allDeclarations = JArrayList<Declaration>(declarations.size());
           value changedPackages = HashSet<Package>();
           
           allDeclarations.addAll(declarations);
           
           for (declaration in declarations) {
               Unit? unit = declaration.unit;
               if (exists unit) {
                   changedPackages.add(unit.\ipackage);
               }
               retrieveInnerDeclarations(declaration, allDeclarations);
           }
           for (decl in allDeclarations) {
               String fqn = getToplevelQualifiedName(decl.container.qualifiedNameString, decl.name);
               _sourceDeclarations.remove(fqn);
           }
           
           super.removeDeclarations(allDeclarations);
           for (changedPackage in changedPackages) {
               loadedPackages.remove(javaString(cacheKeyByModule(changedPackage.\imodule, changedPackage.nameAsString)));
           }
           mustResetLookupEnvironment = true;
       }
       runWithLock(do);
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
       for (member in members) {
           retrieveInnerDeclarations(member, allDeclarations);
       }
   }
   
   shared void clearCachesOnPackage(String packageName) {
       void do() {
           JList<JString> keysToRemove = JArrayList<JString>(classMirrorCache.size());
           for (element in classMirrorCache.entrySet()) {
               if (!element.\ivalue exists, exists className = element.key) {
                   String classPackageName = className.replaceAll("\\.[^\\.]+$", "");
                   if (classPackageName == packageName) {
                       keysToRemove.add(className);
                   }
               }
           }
           for (keyToRemove in keysToRemove) {
               classMirrorCache.remove(keyToRemove);
           }
           Package pkg = findPackage(packageName);
           value packageCacheKey = cacheKeyByModule(pkg.\imodule, packageName);
           loadedPackages.remove(javaString(packageCacheKey));
           packageExistence.remove(packageCacheKey);
           mustResetLookupEnvironment = true;
       }
       runWithLock(do);
   }
   
   shared void clearClassMirrorCacheForClass(BaseIdeModule mod, String classNameToRemove)
           => runWithLock(() {
               classMirrorCache.remove(cacheKeyByModule(mod, classNameToRemove));
               mustResetLookupEnvironment = true;
           });
   
   shared actual void setupSourceFileObjects(JList<out Object> treeHolders)
           => runWithLock(() {
               addSourcePhasedUnits(treeHolders, true);
           });
   
    shared void addSourcePhasedUnits(JList<out Object> treeHolders, Boolean isSourceToCompile)
            => runWithLock(() {
               for (treeHolder in treeHolders) {
                   if (is PhasedUnit treeHolder) {
                       value pkgName = treeHolder.\ipackage.qualifiedNameString;
                       treeHolder.compilationUnit.visit(object extends SourceDeclarationVisitor(){
                           shared actual void loadFromSource(Tree.Declaration decl) {
                               if (exists id=decl.identifier) {
                                   String fqn = getToplevelQualifiedName(pkgName, id.text);
                                   if (! _sourceDeclarations.defines(fqn)) {
                                       _sourceDeclarations[fqn]
                                            = SourceDeclarationHolder(treeHolder, decl, isSourceToCompile);
                                   }
                               }
                           }
                           shared actual void loadFromSource(Tree.ModuleDescriptor that) {}

                           shared actual void loadFromSource(Tree.PackageDescriptor that) {}
                       });
                   }
               }
           });

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
   
    shared actual Module? findModuleForClassMirror(ClassMirror classMirror) => 
            lookupModuleByPackageName(
               getPackageNameForQualifiedClassName(classMirror));
   
    shared actual void loadJDKModules() =>
            super.loadJDKModules();
   
    shared actual LazyPackage findOrCreateModulelessPackage(String pkgName) =>
            callWithLock(() => unsafeCast<LazyPackage>(findPackage(pkgName)));
   
    shared actual Boolean isModuleInClassPath(Module mod) {
       if (mod.signature in modulesInClassPath) {
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

    shared actual Boolean fullyExportMavenDependencies =>
            moduleManager.ceylonProject
                ?.configuration?.fullyExportMavenDependencies
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
       for (annotation in decl.annotationList.annotations) {
           if (exists text = annotation.primary.token.text, 
               text == "native") {
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
               return ideModule.containsClass(classRelativePath + ".class")
                   || ideModule.containsClass(classRelativePath + "_.class");
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
       return searchAgain(null, lazyPackage.\imodule,
           lazyPackage.getQualifiedName(lazyPackage.qualifiedNameString, name));
   }

   shared actual Declaration? convertToDeclaration(Module ideModule, String typeName,
       DeclarationType declarationType) {
       return let (do = () {
           value foundSourceDeclaration = sourceDeclarations[getToplevelQualifiedName(typeName)];
           if (exists foundSourceDeclaration,
               !forceLoadFromBinaries(foundSourceDeclaration.astDeclaration)) {
               return foundSourceDeclaration.modelDeclaration;
           }
           
           variable Declaration? result = null;
           try {
               result = super.convertToDeclaration(ideModule, typeName, declarationType);
           } catch(RuntimeException e) {
               platformUtils.log(Status._ERROR, "Cannot convert type name \"``typeName``\" to a Declaration", e);
           }

           if (exists foundSourceDeclaration, !result exists) {
               result = foundSourceDeclaration.modelDeclaration;
           }
           return result;
       }) callWithLock(do);
   }
   
   shared actual Declaration? convertToDeclaration(Module ideModule, ClassMirror classMirror,
        DeclarationType declarationType)
           => super.convertToDeclaration(ideModule, classMirror, declarationType);
   
   
   shared formal ClassMirror? buildClassMirrorInternal(String string);

   shared actual ClassMirror? lookupNewClassMirror(Module ideModule, String name) {
       return let (do = () {
           String topLevelPartiallyQuotedName = getToplevelQualifiedName(name);
           variable SourceDeclarationHolder? foundSourceDeclaration = sourceDeclarations.get(topLevelPartiallyQuotedName);
           if (exists sourceDeclaration=foundSourceDeclaration,
               !forceLoadFromBinaries(
               sourceDeclaration.astDeclaration)) {
               return SourceClass(sourceDeclaration);
           }
           
           variable ClassMirror? classMirror = buildClassMirrorInternal(JVMModuleUtil.quoteJavaKeywords(name));
           if (! classMirror exists 
               && lastPartHasLowerInitial(name)
                   && !name.endsWith("_")) {
               // We have to try the unmunged name first, so that we find the symbol
               // from the source in preference to the symbol from any 
               // pre-existing .class file
               classMirror = buildClassMirrorInternal(JVMModuleUtil.quoteJavaKeywords(name + "_"));
           }
           
           if (exists existingMirror = classMirror) {
               value classMirrorModule = findModuleForClassMirror(existingMirror);
               if (!exists classMirrorModule) {
                   logVerbose("Found a class mirror with no module");
                   return null;
               }
               // make sure it's imported
               if (isImported(ideModule, classMirrorModule)) {
                   return classMirror;
               }
               logVerbose("Found a class mirror that is not imported: "+name);
               return null;
           } else {
               if (exists sourceDeclaration = foundSourceDeclaration) {
                   return SourceClass(sourceDeclaration);
               }
               
               return null;
           }
           
       })
       callWithLock(do);
   }
   
   shared formal void addModuleToClasspathInternal(ArtifactResult? artifact);

   shared actual void addModuleToClassPath(Module ideModule, ArtifactResult? artifact) {
       if(exists artifact, is LazyModule ideModule) {
           ideModule.loadPackageList(artifact);
       }
       
       if (is BaseIdeModule ideModule) {
           if (ideModule != languageModule 
               && (ideModule.isCeylonBinaryArchive 
                    || ideModule.isJavaBinaryArchive)) {
               addModuleToClasspathInternal(artifact);
           }
       }
       modulesInClassPath.add(ideModule.signature);
   }
   
   shared formal Unit? newCompiledUnit(LazyPackage pkg, IdeClassMirror classMirror);

   shared actual Unit getCompiledUnit(LazyPackage pkg, ClassMirror? classMirror) {
       variable Unit? unit = null;
       if (is IdeClassMirror classMirror) {
           value unitName = classMirror.fileName;
           
           if (!classMirror.isBinary,
               exists foundUnit = {*pkg.units}.find((u) => u.filename == unitName)) {
               // This search is for source Java classes since several classes might have the same file name 
               //  and live inside the same Java source file => into the same Unit
               return foundUnit;
           }
           
           unit = newCompiledUnit(pkg, classMirror);
       }
       
       if (exists u = unit) {
           return u;
       }
       else {
           JString key = javaString(getPackageCacheKey(pkg));
           unit = unitsByPackage[key];
           if (exists u = unit) {
               return u;
           }
           else {
               value newUnit = newPackageTypeFactory(pkg);
               newUnit.\ipackage = pkg;
               unitsByPackage[key] = newUnit;
               return newUnit;
           }
       }
   }

   shared actual default void logError(String message) {
       platformUtils.log(Status._ERROR, message);
   }
   
   shared actual default void logWarning(String message) {
       platformUtils.log(Status._WARNING, message);
   }
   
   shared actual default void logVerbose(String message) {
       platformUtils.log(Status._DEBUG, message);
   }
   
   shared void setModuleAndPackageUnits() {
       for (ideModule in moduleManager.modules.listOfModules) {
           if (is BaseIdeModule ideModule, 
               ideModule.isCeylonBinaryArchive) {
               for (p in ideModule.packages) {
                   if (!p.unit exists) {
                       ClassMirror? packageClassMirror 
                               = lookupClassMirror(ideModule, p.qualifiedNameString + "." + NamingBase.packageDescriptorClassName)
                            else lookupClassMirror(ideModule, p.qualifiedNameString + "." + NamingBase.packageDescriptorClassName.rest);
                       // some modules do not declare their main package, because they don't have any declaration to share
                       // there, for example, so this can be null
                       if (is IdeClassMirror pcm = packageClassMirror) {
                           assert (is LazyPackage p);
                           p.unit = newCompiledUnit(p, pcm);
                       }
                   }
                   if (p.nameAsString == ideModule.nameAsString) {
                       if (!ideModule.unit exists) {
                           ClassMirror? moduleClassMirror 
                                   = lookupClassMirror(ideModule, p.qualifiedNameString + "." + NamingBase.moduleDescriptorClassName)
                                else lookupClassMirror(ideModule, p.qualifiedNameString + "." + NamingBase.oldModuleDescriptorClassName);
                           if (is IdeClassMirror mcm = moduleClassMirror) {
                               assert (is LazyPackage p);
                               ideModule.unit = newCompiledUnit(p, mcm);
                           }
                       }
                   }
               }
           }
       }
   }
}

shared abstract class IdeModelLoader<NativeProject, NativeResource, NativeFolder, NativeFile, JavaClassRoot, JavaClassOrInterface> extends BaseIdeModelLoader 
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & JavaModelServicesConsumer<JavaClassRoot> 
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared new (
        IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> moduleManager,
        IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile> moduleSourceMapper,
        Modules modules
    ) extends BaseIdeModelLoader(moduleManager, moduleSourceMapper, modules){
    }
    
    shared actual default IdeModuleManagerAlias moduleManager => 
            unsafeCast<IdeModuleManagerAlias>(super.moduleManager);
    
    shared actual default IdeModuleSourceMapperAlias moduleSourceMapper => 
            unsafeCast<IdeModuleSourceMapperAlias>(super.moduleSourceMapper);

    shared actual Unit? newCompiledUnit(LazyPackage pkg, IdeClassMirror classMirror) {
        Unit unit;
        JavaClassRoot? typeRoot = javaModelServices.getJavaClassRoot(classMirror);
        if (! exists typeRoot) {
            return null;
        }
        
        String fileName = classMirror.fileName;
        
        String relativePath = "/".join (
            {*pkg.name}.map((name) => Util.quoteIfJavaKeyword(name.string)).chain {fileName});
                
        String fullPath = classMirror.fullPath;
        
        if (!classMirror.isBinary) {
            if (is IdeModuleAlias ideModule = pkg.\imodule) {
                if (exists originalProject = ideModule.originalProject) {
                    unit = javaModelServices.newCrossProjectJavaCompilationUnit(originalProject, typeRoot, relativePath,
                        fileName, fullPath, pkg);
                } else {
                    unit = javaModelServices.newJavaCompilationUnit(typeRoot, relativePath, fileName,
                        fullPath, pkg);
                }
            } else {
                unit = javaModelServices.newJavaCompilationUnit(typeRoot, relativePath, fileName,
                    fullPath, pkg);
            }
        }
        else {
            if (classMirror.isCeylon) {
                if (is IdeModuleAlias ideModule = pkg.\imodule) {
                    CeylonProjectAlias? originalProject = ideModule.originalProject;
                    if (exists originalProject) {
                        unit = javaModelServices.newCrossProjectBinaryUnit(typeRoot, relativePath,
                            fileName, fullPath, pkg);
                    } else {
                        unit = javaModelServices.newCeylonBinaryUnit(typeRoot, relativePath,
                            fileName, fullPath, pkg);
                    }
                } else {
                    unit = javaModelServices.newCeylonBinaryUnit(typeRoot, fileName, relativePath, fullPath, pkg);
                }
            }
            else {
                unit = javaModelServices.newJavaClassFile(typeRoot, relativePath, fileName,
                    fullPath, pkg);
            }
        }
        
        return unit;
    }
    
    shared formal String typeName(JavaClassOrInterface type);
    shared formal Boolean typeExists(JavaClassOrInterface type);

    shared formal class PackageLoader(ideModule) {
        shared BaseIdeModule ideModule;        
        
        "Performs any pre-requisite action that might be required 
         before being able to check for package existence or load its members"
        shared default void preLoadPackage(String quotedPackageName) => noop();
        
        "Performs any pre-requisite action that might be required 
         before being able to load the package members"
        shared default void populatePackage(String quotedPackageName) => noop();
        
        "Checks if the given package exists"
        shared formal Boolean packageExists(String quotedPackageName);
        
        "Returns the various *existing* members (class of Interface) of a package, 
         or [[null]] if the package itself doesn't exist"
        shared formal {JavaClassOrInterface*}? packageMembers(String quotedPackageName);
        
        "Returns [[true]] when the Java type (class of interface) must be omitted
         during package member loading. This happens in the following cases:
         - "
        shared formal Boolean shouldBeOmitted(JavaClassOrInterface type);
    }
    
    shared actual Boolean loadPackage(Module mod, variable String packageName, Boolean loadDeclarations) {
        return let(do = (){
            assert(is BaseIdeModule mod);
            packageName = Util.quoteJavaKeywords(packageName);
            value cacheKey = cacheKeyByModule(mod, packageName);
            if(loadDeclarations) {
                if(!loadedPackages.add(javaString(cacheKey))) {
                    // If declarations were already loaded for this package
                    return true;
                }
            } else {
                value packageExists = packageExistence.get(cacheKey);
                if(exists packageExists) {
                    return packageExists;
                }
            }
            
            value packageLoader = PackageLoader(mod);
            
            packageLoader.preLoadPackage(packageName);
            if (!loadDeclarations) {
                value itExists = packageLoader.packageExists(packageName);
                packageExistence[cacheKey] = itExists;
                return itExists;
            }
            
            packageLoader.populatePackage(packageName);
            
            if (exists members = packageLoader.packageMembers(packageName)) {
                members
                    .map((type) 
                            => [getToplevelQualifiedName(packageName, typeName(type)), type])
                    .filter ((member) => 
                            let([fqn,type] = member)
                            ! any { 
                                packageLoader.shouldBeOmitted(type),
                                sourceDeclarations.defines(fqn),
                                isTypeHidden(mod, fqn)
                            } && typeExists(type))
                    .each ((member) {
                            value [fqn,type] = member;
                            // Some languages like Scala generate classes like com.foo.package which we would
                            // quote to com.foo.$package, which does not exist, so we'd get a null leading to an NPE
                            // So ATM we just avoid it, presumably we don't support what it does anyways
                            if(exists classMirror = lookupClassMirror(mod, fqn)) {
                                convertToDeclaration(mod, classMirror, DeclarationType.\iVALUE);
                            }
                        });

                if(mod.nameAsString == javaBaseModuleName
                    && packageName == "java.lang") {
                    loadJavaBaseArrays();
                }

                return true;
            } else {
                return false;
            }
        }) callWithLock(do);
    }
}