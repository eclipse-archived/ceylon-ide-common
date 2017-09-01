import ceylon.collection {
    HashMap,
    HashSet,
    ArrayList,
    MutableSet,
    MutableList
}

import com.redhat.ceylon.cmr.api {
    ArtifactContext
}
import com.redhat.ceylon.cmr.impl {
    AbstractRepository,
    NpmContentStore
}
import com.redhat.ceylon.cmr.spi {
    ContentStore
}
import com.redhat.ceylon.common {
    Constants,
    Versions
}
import com.redhat.ceylon.compiler.js.loader {
    NpmAware,
    NpmPackage
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnitMap,
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile,
    ClosableVirtualFile
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.util {
    NewlineFixingStringStream
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit,
    CrossProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    synchronize,
    equalsWithNulls,
    Path,
    SingleSourceUnitPackage,
    unsafeCast,
    retrieveMappingFile,
    searchCeylonFilesForJavaImplementations
}
import com.redhat.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile,
    BaseResourceVirtualFile
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult,
    JDKUtils,
    ArtifactResultType
}
import com.redhat.ceylon.model.loader.model {
    LazyModule
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Package,
    Unit,
    ModelUtil,
    Declaration,
    TypeDeclaration
}

import java.io {
    File,
    IOException
}
import java.lang {
    Types {
        nativeString
    },
    JString=String
}
import java.lang.ref {
    WeakReference,
    SoftReference
}
import java.util {
    JList=List,
    Arrays
}
import java.util.zip {
    ZipFile,
    ZipEntry
}

import org.antlr.runtime {
    CommonToken,
    CommonTokenStream
}

shared class ModuleType
        of projectModule
         | ceylonSourceArchive
         | ceylonBinaryArchive
         | javaBinaryArchive
         | npmModule
         | javaSdkModule
         | unknown {
    shared actual String string;
    shared new projectModule { string = "PROJECT_MODULE"; }
    shared new ceylonSourceArchive { string = "CEYLON_SOURCE_ARCHIVE"; }
    shared new ceylonBinaryArchive { string = "CEYLON_BINARY_ARCHIVE"; }
    shared new javaBinaryArchive { string = "JAVA_BINARY_ARCHIVE"; }
    shared new javaSdkModule { string = "SDK_MODULE"; }
    shared new npmModule { string = "NPM_MODULE"; }
    shared new unknown { string = "UNKNOWN"; }
}

shared abstract class BaseIdeModule()
        extends LazyModule()
        satisfies NpmAware {
    
    shared actual variable String? npmPath = null;
    
    shared formal BaseCeylonProject? ceylonProject;
    
    shared formal BaseIdeModuleManager moduleManager;
    shared formal BaseIdeModuleSourceMapper moduleSourceMapper;
    
    shared formal String? namespace;
    shared formal ArtifactResultType artifactType;
    
    shared formal variable Boolean isProjectModule;
    shared formal Boolean isDefaultModule;
    shared formal Boolean isJDKModule;
    shared formal Boolean isCeylonArchive;
    shared formal Boolean isJavaBinaryArchive;
    shared formal Boolean isCeylonBinaryArchive;
    shared formal Boolean isSourceArchive;
    shared formal Boolean isUnresolved;
    
    shared formal String repositoryDisplayString;
    
    shared formal String? getCeylonDeclarationFile(String? sourceUnitRelativePath);
    
    shared formal File? artifact;
    
    shared formal void setArtifactResult(ArtifactResult artifactResult);
    shared formal void setSourcePhasedUnits(ExternalModulePhasedUnits modulePhasedUnits);
    
    shared formal Map<String, String> classesToSources;
    
    shared formal Boolean containsJavaImplementations();
    
    shared formal String? toSourceUnitRelativePath(String? binaryUnitRelativePath);
    
    shared formal String? getJavaImplementationFile(String? ceylonFileRelativePath);
    
    shared formal {String*} toBinaryUnitRelativePaths(String? sourceUnitRelativePath);
    
    shared formal {PhasedUnit*} phasedUnits;
    shared JList<PhasedUnit> phasedUnitsAsJavaList => Arrays.asList(*phasedUnits);

    shared formal ExternalPhasedUnit? getPhasedUnit(
        "Either the **absolute path** or a [[virtual file|VirtualFile]]
         used to identify and retrieve the [[phased unit|PhasedUnit]]"
        String | Path | VirtualFile from);
    
    shared formal ExternalPhasedUnit? getPhasedUnitFromRelativePath(String relativePathToSource);
    
    shared formal void removedOriginalUnit(String relativePathToSource);
    shared formal void addedOriginalUnit(String relativePathToSource);
    
    shared formal String? sourceArchivePath;
    
    shared formal BaseCeylonProject? originalProject;
    shared formal BaseIdeModule? originalModule;
    
    shared formal Boolean containsClass(String className);
    
    shared formal {Module*} referencingModules;
    shared formal {Module*} transitiveDependencies;
    
    shared JList<Module> referencingModulesAsJavaList
            => Arrays.asList(*referencingModules);
    shared JList<Module> transitiveDependenciesAsJavaList
            => Arrays.asList(*transitiveDependencies);
    
    shared formal Boolean resolutionFailed;
    shared formal void setResolutionException(Exception resolutionException);
    
    shared formal {BaseIdeModule*} moduleInReferencingProjects;
    
    shared JList<BaseIdeModule> moduleInReferencingProjectsAsJavaList
            => Arrays.asList(*moduleInReferencingProjects);
    
    shared formal void refresh();
}

shared alias AnyIdeModule => IdeModule<out Anything, out Anything, out Anything, out Anything>;

shared abstract class IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseIdeModule()
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    variable ModuleType? _moduleType = null;
    variable String _repositoryDisplayString = "";
    variable String? _namespace = null;
    variable File? _artifact = null;
    variable WeakReference<ExternalModulePhasedUnits>? sourceModulePhasedUnits = null;
    variable BinaryPhasedUnits? binaryModulePhasedUnits = null;
    variable MutableList<String> sourceRelativePaths = ArrayList<String>();
    variable Map<String, String> _classesToSources = emptyMap;
    variable Map<String, String> javaImplFilesToCeylonDeclFiles = HashMap<String, String>();
    variable String? _sourceArchivePath = null;
    variable WeakReference<CeylonProjectAlias>? _originalProject = WeakReference<CeylonProjectAlias>(null);
    variable IdeModuleAlias? _originalModule = null;
    variable MutableSet<String> originalUnitsToRemove = HashSet<String>();
    variable MutableSet<String> originalUnitsToAdd = HashSet<String>();
    variable ArtifactResultType _artifactType = ArtifactResultType.other;
    variable Exception? resolutionException = null;
    variable ModuleDependencies? _projectModuleDependencies = null;

    shared actual CeylonProjectAlias? ceylonProject => moduleManager.ceylonProject;
    
    shared formal actual IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> moduleManager;
    shared formal actual IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile> moduleSourceMapper;
    
    shared actual Boolean isProjectModule => 
            equalsWithNulls(ModuleType.projectModule, _moduleType);
    assign isProjectModule =>
        _moduleType = ModuleType.projectModule;
    
    isDefaultModule => 
            this == moduleManager.modules.defaultModule;
    
    shared actual Boolean isJDKModule {
        synchronize {
            on = this;
            void do() {
                if (! _moduleType exists) {
                    if (JDKUtils.isJDKModule(nameAsString)
                     || JDKUtils.isOracleJDKModule(nameAsString)) {
                        _moduleType = ModuleType.javaSdkModule;
                    }
                }
            }
        };
        return if (exists existingModuleType = _moduleType)
        then ModuleType.javaSdkModule == existingModuleType
        else false;
    }
    
    isCeylonArchive => 
            isCeylonBinaryArchive || isSourceArchive;
    
    isJavaBinaryArchive => 
            equalsWithNulls(ModuleType.javaBinaryArchive, _moduleType);
    
    isCeylonBinaryArchive => 
            equalsWithNulls(ModuleType.ceylonBinaryArchive, _moduleType);
    
    isSourceArchive => 
            equalsWithNulls(ModuleType.ceylonSourceArchive, _moduleType);
    
    isUnresolved => !artifact exists && !available;
    
    repositoryDisplayString =>
            if (isJDKModule) 
                then "Java SE Modules"
                else _repositoryDisplayString;
    
    function switchExtension(String sap, String oldExtension, String newExtension) => 
            sap.initial(sap.size - oldExtension.size) + newExtension;
    
    "This method was initially protected : it's aimed to be used by the subclasses, but not by external clients"
    shared File? returnCarFile() {
        if (isCeylonBinaryArchive) {
            return _artifact;
        }
        if (isSourceArchive) {
            assert(exists sap=_sourceArchivePath);
            return File(switchExtension(sap, ArtifactContext.src, ArtifactContext.car));
        }
        return null;
    }
    
    shared actual String? getCeylonDeclarationFile(String? sourceUnitRelativePath) {
        if (!exists sourceUnitRelativePath) {
            return null;
        }
        if (sourceUnitRelativePath.endsWith(".ceylon")) {
            return sourceUnitRelativePath;
        }
        return javaImplFilesToCeylonDeclFiles.get(sourceUnitRelativePath);
    }
    
    class BinaryPhasedUnits() extends PhasedUnitMap<ExternalPhasedUnit, SoftReference<ExternalPhasedUnit>>() {
        variable MutableSet<String> sourceCannotBeResolved = HashSet<String>();
        assert(exists existingSourceArchivePath=_sourceArchivePath);
        String fullPathPrefix = existingSourceArchivePath.string + "!/";
        
        shared void putRelativePath(String sourceRelativePath) {
            String path = fullPathPrefix + sourceRelativePath;
            phasedUnitPerPath[nativeString(path)] = SoftReference<ExternalPhasedUnit>(null);
            relativePathToPath[nativeString(sourceRelativePath)] = nativeString(path);
        }
        
        shared actual ExternalPhasedUnit? getPhasedUnit(String path) {
            if (!phasedUnitPerPath.containsKey(nativeString(path))) {
                if (path.endsWith(".java")) {
                    // Case of a Ceylon file with a Java implementation, the classesToSources key is the Java source file.
                    String? ceylonFileRelativePath = getCeylonDeclarationFile(path.replace("``existingSourceArchivePath``!/", ""));
                    if (exists ceylonFileRelativePath) {
                        return super.getPhasedUnit("``existingSourceArchivePath``!/``ceylonFileRelativePath``");
                    }
                }
                return null;
            }
            return super.getPhasedUnit(path);
        }
        
        shared actual ExternalPhasedUnit? getPhasedUnitFromRelativePath(variable String relativePath) {
            if (relativePath.startsWith("/")) {
                relativePath = relativePath.spanFrom(1);
            }
            if (!relativePathToPath.containsKey(nativeString(relativePath))) {
                if (relativePath.endsWith(".java")) {
                    String? ceylonFileRelativePath = getCeylonDeclarationFile(relativePath);
                    if (exists ceylonFileRelativePath) {
                        return super.getPhasedUnitFromRelativePath(ceylonFileRelativePath);
                    }
                }
                return null;
            }
            return super.getPhasedUnitFromRelativePath(relativePath);
        }
        
        shared actual ExternalPhasedUnit? fromStoredType(SoftReference<ExternalPhasedUnit> storedValue, String path) {
            variable ExternalPhasedUnit? result = storedValue.get();
            if (! result exists) {
                if (!path in sourceCannotBeResolved) {
                    result = buildPhasedUnitForBinaryUnit(path);
                    if (exists existingResult=result) {
                        phasedUnitPerPath[nativeString(path)] = toStoredType(existingResult);
                    }
                    else {
                        sourceCannotBeResolved.add(path);
                    }
                }
            }
            return result;
        }
        
        shared actual void addInReturnedList(JList<ExternalPhasedUnit> list, ExternalPhasedUnit? phasedUnit) {
            if (exists phasedUnit) {
                list.add(phasedUnit);
            }
        }
        
        toStoredType(ExternalPhasedUnit phasedUnit) 
                => SoftReference<ExternalPhasedUnit>(phasedUnit);
        
        shared actual void removePhasedUnitForRelativePath(String relativePath) {
            JString relPath = nativeString(relativePath);
            JString? fullPath = relativePathToPath.get(relPath);
            relativePathToPath.remove(relPath);
            phasedUnitPerPath.remove(fullPath);
        }
        
    }
    
    artifact => _artifact;
    
    namespace => _namespace;

    value this_ => this;
    setArtifactResult(ArtifactResult artifactResult) =>
        synchronize {
            on = this;
            void do() {
                value existingArtifact = artifactResult.artifact();
                _artifact = existingArtifact;
                _namespace = artifactResult.namespace();
                _repositoryDisplayString = artifactResult.repositoryDisplayString();
                if (_repositoryDisplayString == Constants.repoUrlCeylon.replaceFirst("https", "http")) {
                    _repositoryDisplayString = Constants.repoUrlCeylon;
                }
                if (existingArtifact.name.endsWith(ArtifactContext.src)) {
                    _moduleType = ModuleType.ceylonSourceArchive;
                }
                else if (existingArtifact.name.endsWith(ArtifactContext.car)) {
                    _moduleType = ModuleType.ceylonBinaryArchive;
                }
                else if (existingArtifact.name.endsWith(ArtifactContext.jar)) {
                    _moduleType = ModuleType.javaBinaryArchive;
                }
                else if (equalsWithNulls("npm", artifactResult.namespace())) {
                    _moduleType = ModuleType.npmModule;
                    assert (is AbstractRepository repository = artifactResult.repository());
                    if (is NpmContentStore contentStore = repository.root.getService(`ContentStore`)) {
                        value absoluteNpmPath = artifactResult.artifact().absolutePath;
                        for (baseDir in contentStore.baseDirectories) {
                            if (Path(baseDir.absolutePath).isPrefixOf(Path(absoluteNpmPath))) {
                                value relativeNpmPath = absoluteNpmPath.substring(baseDir.absolutePath.size+1);
                                npmPath = relativeNpmPath;
                                value pkgName
                                        = nameAsString
                                            .replace("-", ".")
                                            .replace("_", ".")
                                            .replace(":", ".");
                                value pkg = NpmPackage(this_, pkgName);
                                object pkgUnit
                                        extends IdeUnit.init(
                                                    artifactResult.artifact().name,
                                                    relativeNpmPath,
                                                    absoluteNpmPath,
                                                    pkg) {
                                    sourceFileName = null;
                                    sourceFullPath = null;
                                    sourceRelativePath = null;
                                }
                                pkg.unit = pkgUnit;
                                packages.add(pkg);
                                
                                jsMajor = Versions.jsBinaryMajorVersion;
                                jsMinor = Versions.jsBinaryMinorVersion;
                                available = true;
                                break;
                            }
                        }
                    }
                }
                _artifactType = artifactResult.type();
                if (isCeylonBinaryArchive) {
                    String carPath = existingArtifact.path;
                    _sourceArchivePath = switchExtension {
                        sap = carPath;
                        oldExtension = ArtifactContext.car;
                        newExtension = ArtifactContext.src;
                    };
                    try {
                        fillSourceRelativePaths();
                    }
                    catch (e) {
                        platformUtils.log(Status._WARNING, "Cannot find the source archive for the Ceylon binary module " + signature, e);
                    }
                    value theBInaryPhasedUnits = BinaryPhasedUnits();
                    for (sourceRelativePath in sourceRelativePaths) {
                        variable String pathToPut = sourceRelativePath;
                        if (sourceRelativePath.endsWith(".java")) {
                            if (exists ceylonRelativePath = javaImplFilesToCeylonDeclFiles.get(sourceRelativePath)) {
                                pathToPut = ceylonRelativePath;
                            }
                        }
                        theBInaryPhasedUnits.putRelativePath(pathToPut.string);
                    }
                    binaryModulePhasedUnits = theBInaryPhasedUnits;
                }
                if (isSourceArchive) {
                    _sourceArchivePath = existingArtifact.path;
                    try {
                        fillSourceRelativePaths();
                    }
                    catch (e) {
                        e.printStackTrace();
                    }
                    sourceModulePhasedUnits = WeakReference<ExternalModulePhasedUnits>(null);
                }
                
                if (is CeylonProjectAlias moduleOriginalProject = moduleManager
                                .searchForOriginalProject(existingArtifact)) {
                    _originalProject = WeakReference(moduleOriginalProject);
                }
                
                if (isJavaBinaryArchive) {
                    value carPath = existingArtifact.path;
                    _sourceArchivePath = switchExtension(
                        carPath, 
                        ArtifactContext.jar, 
                        if (artifactResult.type() == ArtifactResultType.maven) 
                        then ArtifactContext.legacySrc 
                        else ArtifactContext.src);
                }
            }
        };
    
    void fillSourceRelativePaths() {
        _classesToSources = retrieveMappingFile(returnCarFile());
        sourceRelativePaths.clear();
        
        assert(exists existingSourceArchivePath=_sourceArchivePath);
        File sourceArchiveFile = File(existingSourceArchivePath);
        variable Boolean sourcePathsFilled = false;
        if (sourceArchiveFile.\iexists()) {
            ZipFile sourceArchive;
            try {
                sourceArchive = ZipFile(sourceArchiveFile);
                try {
                    value entries = sourceArchive.entries();
                    while (entries.hasMoreElements()) {
                        ZipEntry entry = entries.nextElement();
                        sourceRelativePaths.add(entry.name);
                    }
                    sourcePathsFilled = true;
                }
                finally {
                    sourceArchive.close();
                }
            }
            catch (IOException e) {
                e.printStackTrace();
                sourceRelativePaths.clear();
            }
        }
        if (!sourcePathsFilled) {
            _classesToSources.items.each(sourceRelativePaths.add);
        }
        if (sourceArchiveFile.\iexists()) {
            javaImplFilesToCeylonDeclFiles =
                searchCeylonFilesForJavaImplementations {
                    sources = _classesToSources.items;
                    sourceArchive = File(existingSourceArchivePath);
                };
        } else {
            platformUtils.log(Status._WARNING,
                "No source file found for archive :`` 
                returnCarFile()?.absolutePath else "unknown" ``");
            javaImplFilesToCeylonDeclFiles = emptyMap;
        }
    }
    
    shared actual Package? getPackage(variable String name) {
        if (! equalsWithNulls(_moduleType, ModuleType.npmModule)) {
            return super.getPackage(name);
        } else {
            return getDirectPackage(name);
        }
    }
    
    setSourcePhasedUnits(ExternalModulePhasedUnits modulePhasedUnits) =>
            synchronize { 
                on = this; 
                do() => sourceModulePhasedUnits = WeakReference(modulePhasedUnits);
            };
    
    artifactType => _artifactType;
    
    shared actual Map<String, String> classesToSources {
        if (_classesToSources.empty && nameAsString == "java.base") {
            assert (is AnyIdeModule languageIdeModule = languageModule);
            _classesToSources = HashMap {
                for (key->item in languageIdeModule.classesToSources)
                if (key.startsWith("com/redhat/ceylon/compiler/java/language/"))
                key.replace("com/redhat/ceylon/compiler/java/language/", "java/lang/") -> item
            };
        }
        return _classesToSources;
    }
    
    containsJavaImplementations() =>
            _classesToSources.items
            .any((sourceFile) => sourceFile.endsWith(".java"));
    
    toSourceUnitRelativePath(String? binaryUnitRelativePath) =>
            if (exists binaryUnitRelativePath)
            then classesToSources[binaryUnitRelativePath]
            else null;
    
    getJavaImplementationFile(String? ceylonFileRelativePath) =>
            if (exists ceylonFileRelativePath) 
            then javaImplFilesToCeylonDeclFiles
                .find((_->declFile) => declFile == ceylonFileRelativePath)?.key
            else null;
    
    toBinaryUnitRelativePaths(String? sourceUnitRelativePath) =>
            if (exists sourceUnitRelativePath) 
            then _classesToSources
                .filter((_->source) => source == sourceUnitRelativePath)
                .map(Entry.key) else [];
    
    alias AnyPhasedUnitMap => PhasedUnitMap<out PhasedUnit, out PhasedUnit | SoftReference<ExternalPhasedUnit>>;
    
    Result doWithPhasedUnitsObject<Result>(Result action(AnyPhasedUnitMap phasedUnitMap), Result defaultValue) {
        variable AnyPhasedUnitMap? phasedUnitMap = null;
        if (isCeylonBinaryArchive) {
            phasedUnitMap = binaryModulePhasedUnits;
        }
        if (isSourceArchive) {
            phasedUnitMap = sourceModulePhasedUnits?.get();
        }
        if (exists theMap=phasedUnitMap) {
            return synchronize { 
                on = theMap; 
                do() => action(theMap);
            };
        }
        return defaultValue;
    }
    
    phasedUnits =>
            doWithPhasedUnitsObject { 
                action(AnyPhasedUnitMap phasedUnitMap) 
                        => { *phasedUnitMap.phasedUnits };
                defaultValue = []; 
            };
    
    shared Boolean containsPhasedUnitWithRelativePath(String relativePath) =>
            doWithPhasedUnitsObject { 
                action(AnyPhasedUnitMap phasedUnitMap) 
                        => phasedUnitMap.containsRelativePath(relativePath);
                defaultValue = false; 
            };
    
    shared actual ExternalPhasedUnit? getPhasedUnit(
        "Either the **absolute path** or a [[virtual file|VirtualFile]]
         used to identify and retrieve the [[phased unit|PhasedUnit]]"
        String | Path | VirtualFile from) =>
            if (exists existingSourceArchivePath=_sourceArchivePath) 
            then doWithPhasedUnitsObject {
                function action(AnyPhasedUnitMap phasedUnitMap) {
                    PhasedUnit? phasedUnit;
                    switch (from)
                    case (is Path) {
                        value searchedPrefix = Path("``_sourceArchivePath else ""``!");
                        value relativePath = from.makeRelativeTo(searchedPrefix);
                        phasedUnit = phasedUnitMap.getPhasedUnitFromRelativePath(relativePath.string);
                    }
                    case (is String) {
                        phasedUnit = phasedUnitMap.getPhasedUnit(from);
                    }
                    case (is VirtualFile) {
                        phasedUnit = phasedUnitMap.getPhasedUnit(from);
                    }
                    assert(is ExternalPhasedUnit? phasedUnit);
                    return phasedUnit;
                }
                defaultValue = null; 
            }
            else null;
    
    
    getPhasedUnitFromRelativePath(String relativePathToSource) =>
            doWithPhasedUnitsObject { 
                function action(AnyPhasedUnitMap phasedUnitMap) { 
                    PhasedUnit? phasedUnit = phasedUnitMap.getPhasedUnitFromRelativePath(relativePathToSource);
                    assert(is ExternalPhasedUnit? phasedUnit);
                    return phasedUnit;
                }
                defaultValue = null; 
            };
    
    allVisiblePackages => 
            let(do=() {
                loadAllPackages(HashSet<String>());
                return super.allVisiblePackages;
            }) synchronize(modelLoader, do);
    
    allReachablePackages => 
            let(do = () {
                loadAllPackages(HashSet<String>());
                return super.allReachablePackages;
            }) synchronize(modelLoader, do);
    
    void loadAllPackages(MutableSet<String> alreadyScannedModules) {
        value packageList = listPackages();
        for (packageName in packageList) {
            getPackage(packageName.string);
        }
        
        // now force-load other modules
        for (mi in imports) {
            if (is AnyIdeModule importedModule = mi.\imodule, 
                alreadyScannedModules.add(importedModule.nameAsString)) {
                importedModule.loadAllPackages(alreadyScannedModules);
            }
        }
    }
    
    "This method was initially private. but since it can only be 
     defined in children classes, it has been made shared.
     However it is *not* intended to be used by external classes"
    shared formal Set<String> listPackages();
    
    shared actual void loadPackageList(ArtifactResult artifact) {
        try {
            super.loadPackageList(artifact);
        }
        catch (e) {
            platformUtils.log(Status._ERROR,"Failed loading the package list of module " + signature, e);
        }

        void do() {
            value isLanguageModule
                    = nameAsString
                    == Module.languageModuleName;
            for (pkg in jarPackages) {
                if (isLanguageModule &&
                    !pkg.startsWith(Module.languageModuleName)) {
                    continue;
                }
                modelLoader.findOrCreatePackage(this, pkg.string);
            }
        }
        
        synchronize(modelLoader, do);
    }
    
    shared actual void removedOriginalUnit(String relativePathToSource) {
        if (isProjectModule) {
            return;
        }
        
        originalUnitsToRemove.add(relativePathToSource);
        try {
            if (isCeylonBinaryArchive || 
                (ceylonProject?.isJavaLikeFileName(relativePathToSource) else false)) {
                value unitPathsToSearch = 
                        { relativePathToSource, *toBinaryUnitRelativePaths(relativePathToSource) };
                
                for (relativePathOfUnitToRemove in unitPathsToSearch) {
                    if (exists p = getPackageFromRelativePath(relativePathOfUnitToRemove)) {
                        value units = HashSet<Unit>();
                        try {
                            for (d in p.members) {
                                value u = d.unit;
                                if (u.relativePath == relativePathOfUnitToRemove) {
                                    units.add(u);
                                }
                            }
                        }
                        catch (e) {
                            e.printStackTrace();
                        }
                        for (u in units) {
                            try {
                                for (d in u.declarations) {
                                    suppressWarnings("unusedDeclaration")
                                    value unused = d.members;
                                    // Just to fully load the declaration before 
                                    // the corresponding class is removed (so that 
                                    // the real removing from the model loader
                                    // will not require reading the bindings.
                                }
                            }
                            catch (e) {
                                e.printStackTrace();
                            }
                        }
                    }
                }
            }
        }
        catch (e) {
            e.printStackTrace();
        }
    }
    
    shared actual void addedOriginalUnit(String relativePathToSource) {
        if (isProjectModule) {
            return ;
        }
        originalUnitsToAdd.add(relativePathToSource);
    }
    
    Package? getPackageFromRelativePath(String relativePathOfClassToRemove) {
        String packageName = 
                ModelUtil.formatPath(Arrays.asList(
                    for (seg in relativePathOfClassToRemove.split('/'.equals).exceptLast)
                    nativeString(seg)));
        return findPackageNoLazyLoading(packageName);
    }
    
    """
       could have been done like this also :
       ```
       function findChild(BaseResourceVirtualFile? vf, String pathElement) => 
        if (exists vf) 
        then vf.childrenIterable.find((vf) => pathElement == vf.name.replace("/", ""))
        else null;
        
       value result = sourceUnitRelativePath.split('/'.equals)
       .fold<BaseResourceVirtualFile?>(theSourceArchive)(findChild);
       ```
       but it's longer since there is no way to stop when the path 
       element doesn't match
       """
    ZipEntryVirtualFile? searchInSourceArchive(String sourceUnitRelativePath, ZipFileVirtualFile theSourceArchive) {
        variable BaseResourceVirtualFile archiveEntry = theSourceArchive;
        for (pathElement in sourceUnitRelativePath.split('/'.equals)) {
            for (vf in archiveEntry.childrenIterable) {
                if (pathElement == vf.name.replace("/", "")) {
                    archiveEntry = vf;
                    break;
                }
            } else {
                return null;
            }
        }
        
        return switch(value result = archiveEntry)
        case (is ZipEntryVirtualFile) result
        else null;
    }
    
    sourceArchivePath => _sourceArchivePath;
    
    shared actual CeylonProjectAlias? originalProject =>
            _originalProject?.get();
    
    shared actual IdeModuleAlias? originalModule {
        if (exists p=_originalProject?.get(),
            exists modules=p.modules) {
            if (! _originalModule exists) {
                _originalModule = modules.find(
                    (m) => m.nameAsString == nameAsString 
                            && m.isProjectModule);
            }
            return _originalModule;
        }
        return null;
    }
    
    containsClass(String className) =>
            _classesToSources.defines(className);
    
    alias AnyIdeModule => IdeModule<out Object, out Object, out Object, out Object>;
    
    shared actual void clearCache(TypeDeclaration declaration) {
        clearCacheLocally(declaration);
        if (exists deps = projectModuleDependencies) {
            value clearModuleCacheAction = object satisfies TraversalAction<Module> {
                shared actual void applyOn(Module mod) {
                    if (is AnyIdeModule mod) {
                        mod.clearCacheLocally(declaration);
                    }
                }
                
            };
            deps.doWithReferencingModules(this, clearModuleCacheAction);
            deps.doWithTransitiveDependencies(this, clearModuleCacheAction);
            assert(is AnyIdeModule languageIdeModule=languageModule);
            languageIdeModule.clearCacheLocally(declaration);
        }
    }
    
    void clearCacheLocally(TypeDeclaration declaration) 
            => super.clearCache(declaration);
    
    ModuleDependencies? projectModuleDependencies {
        if (!exists deps=_projectModuleDependencies) {
            value ceylonProject = moduleManager.ceylonProject;
            if (exists ceylonProject) {
                _projectModuleDependencies = ceylonProject.moduleDependencies;
            }
        }
        return _projectModuleDependencies;
    }
    
    referencingModules =>
            switch (value deps = projectModuleDependencies)
            case (is Object) { *deps.getReferencingModules(this) }
            else [];
    
    transitiveDependencies =>
            switch (value deps = projectModuleDependencies)
            case (is Object) { *deps.getTransitiveDependencies(this) }
            else [];
    
    resolutionFailed => resolutionException exists;
    
    shared actual void setResolutionException(Exception resolutionException) {
        this.resolutionException = resolutionException;
    }
    
    shared actual {IdeModuleAlias*} moduleInReferencingProjects {
        if (!isProjectModule) {
            return [];
        }
        
        value project = moduleManager.ceylonProject;
        if (exists project) {
            return project.referencingCeylonProjects
                    .flatMap((p) => (p.modules ?. external else []))
                    .filter((m) => m.signature == signature);
        } else {
            return [];
        }
    }
    
    shared default void encloseOnTheFlyTypechecking(void typechecking())
            => typechecking();

    ExternalPhasedUnit? buildPhasedUnitForBinaryUnit(String? sourceUnitFullPath) {
        if (!_sourceArchivePath exists || !sourceUnitFullPath exists) {
            return null;
        }
        assert(exists existingSourceArchivePath=_sourceArchivePath);
        assert(exists sourceUnitFullPath);
        
        if (!sourceUnitFullPath.startsWith(existingSourceArchivePath.string)) {
            return null;
        }
        variable File sourceArchiveFile = File(existingSourceArchivePath.string);
        if (!sourceArchiveFile.\iexists()) {
            return null;
        }
        variable ExternalPhasedUnit? phasedUnit = null;
        String sourceUnitRelativePath = sourceUnitFullPath.replace("``existingSourceArchivePath``!/", "");
        Package? pkg = getPackageFromRelativePath(sourceUnitRelativePath);
        if (exists pkg) {
            try {
                variable ZipFileVirtualFile? theSourceArchive = null;
                try {
                    theSourceArchive = ZipFileVirtualFile.fromFile(sourceArchiveFile);
                    assert(exists existingSourceArchive = theSourceArchive);
                    String? ceylonSourceUnitRelativePath = getCeylonDeclarationFile(sourceUnitRelativePath);
                    if (exists ceylonSourceUnitRelativePath) {
                        String ceylonSourceUnitFullPath = "``existingSourceArchivePath``!/``ceylonSourceUnitRelativePath``";
                        ZipEntryVirtualFile? archiveEntry = searchInSourceArchive(ceylonSourceUnitRelativePath, existingSourceArchive);
                        if (exists archiveEntry) {
                            assert (exists project = moduleManager.ceylonProject);
                            CeylonLexer lexer = CeylonLexer(NewlineFixingStringStream.fromStream(archiveEntry.inputStream, project.defaultCharset));
                            CommonTokenStream tokenStream = CommonTokenStream(lexer);
                            CeylonParser parser = CeylonParser(tokenStream);
                            Tree.CompilationUnit cu = parser.compilationUnit();
                            value theTokens = unsafeCast<JList<CommonToken>>(tokenStream.tokens);
                            
                            SingleSourceUnitPackage proxyPackage = SingleSourceUnitPackage(pkg, ceylonSourceUnitFullPath);
                            
                            if (exists op = _originalProject?.get()) {
                                phasedUnit = object extends CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(archiveEntry, existingSourceArchive, cu, proxyPackage, moduleManager, outer.moduleSourceMapper, moduleManager.typeChecker, theTokens, op) {
                                    isAllowedToChangeModel(Declaration declaration) =>
                                            !isCentralModelDeclaration(declaration);
                                };
                            }
                            else {
                                phasedUnit = object extends ExternalPhasedUnit(archiveEntry, existingSourceArchive, cu, proxyPackage, moduleManager, outer.moduleSourceMapper, moduleManager.typeChecker, theTokens) {
                                    isAllowedToChangeModel(Declaration declaration) =>
                                            !isCentralModelDeclaration(declaration);
                                };
                            }
                        }
                    }
                }
                catch (e) {
                    value error = StringBuilder();
                    error.append("Unable to read source artifact from ");
                    error.append(theSourceArchive?.string else "<null>");
                    error.append("\ndue to connection error: ").append(e.message);
                    process.writeErrorLine(error.string);
                }
                finally {
                    if (exists existingSourceArchive=theSourceArchive) {
                        existingSourceArchive.close();
                    }
                }
                if (exists existingPhasedUnit = phasedUnit) {
                    encloseOnTheFlyTypechecking(() {
                        existingPhasedUnit.validateTree();
                        existingPhasedUnit.visitSrcModulePhase();
                        existingPhasedUnit.visitRemainingModulePhase();
                        existingPhasedUnit.scanDeclarations();
                        existingPhasedUnit.scanTypeDeclarations(cancelDidYouMeanSearch);
                        existingPhasedUnit.validateRefinement();
                    });
                    moduleManager.model.externalPhasedUnitsTypechecked({existingPhasedUnit}, false);                    
                }
            }
            catch (e) {
                e.printStackTrace();
                phasedUnit = null;
            }
        }
        return phasedUnit;
    }
    
    "Not intented to be called by clients, but to be defined in sub-classes"
    shared formal void refreshJavaModel();
    
    shared actual void refresh() {
        if (originalUnitsToAdd.empty && originalUnitsToRemove.empty) {
            return;
        }
        try {
            doWithPhasedUnitsObject { 
                void action(AnyPhasedUnitMap phasedUnitMap) { 
                    if (isCeylonBinaryArchive) {
                        refreshJavaModel();
                    }
                    for (relativePathToRemove in originalUnitsToRemove) {
                        if (isCeylonBinaryArchive || 
                            (ceylonProject?.isJavaLikeFileName(relativePathToRemove) else false)) {
                            value unitPathsToSearch = { relativePathToRemove,
                                * toBinaryUnitRelativePaths(relativePathToRemove) };
                                
                            for (relativePathOfUnitToRemove in unitPathsToSearch) {
                                if (exists p = getPackageFromRelativePath(relativePathOfUnitToRemove)) {
                                    value units = HashSet<Unit>();
                                    for (d in p.members) {
                                        value u = d.unit;
                                        if (u.relativePath == relativePathOfUnitToRemove) {
                                            units.add(u);
                                        }
                                    }
                                    for (u in units) {
                                        try {
                                            p.removeUnit(u);
                                        }
                                        catch (e) {
                                            e.printStackTrace();
                                        }
                                    }
                                }
                                else {
                                    print("WARNING : The package of the following binary unit (``relativePathOfUnitToRemove``) cannot be found in module ``nameAsString```` if (exists a=artifact) then "(artifact=" + a.absolutePath + ")" else "" ``.");
                                }
                            }
                        }
                        phasedUnitMap.removePhasedUnitForRelativePath(relativePathToRemove);
                    }
                    if (isSourceArchive) {
                        assert(is ExternalModulePhasedUnits phasedUnitMap);
                        variable ClosableVirtualFile? theSourceArchive = null;
                        try {
                            value zipFile = ZipFileVirtualFile.fromFile(File(_sourceArchivePath));
                            theSourceArchive = zipFile;
                            for (relativePathToAdd in originalUnitsToAdd) {
                                if (exists archiveEntry = searchInSourceArchive(relativePathToAdd, zipFile),
                                    exists pkg = getPackageFromRelativePath(relativePathToAdd)) {
                                    phasedUnitMap.parseFileInPackage(archiveEntry, zipFile, pkg);
                                }
                            }
                        }
                        catch (e) {
                            value error = "Unable to read source artifact from
                                           ``_sourceArchivePath else "<null>"
                            ``due to connection error: ``e.message``";
                            process.writeErrorLine(error);
                            throw e;
                        } finally {
                            if (exists zipFile=theSourceArchive) {
                                zipFile.close();
                            }
                        }
                    } else if (isCeylonBinaryArchive, is BinaryPhasedUnits phasedUnits=binaryModulePhasedUnits) {
                        for (relativePathToAdd in originalUnitsToAdd) {
                            phasedUnits.putRelativePath(relativePathToAdd);
                        }
                    }
                    fillSourceRelativePaths();
                    originalUnitsToRemove.clear();
                    originalUnitsToAdd.clear();
                }
                defaultValue = null; 
            };
                
            if (isCeylonBinaryArchive || isJavaBinaryArchive) {
                jarPackages.clear();
                loadPackageList(object satisfies ArtifactResult {
                    visibilityType() => null;
                    version() => null;
                    type()  => null;
                    namespace() => null;
                    name() => null;
                    groupId() => null;
                    artifactId() => null;
                    classifier() => null;
                    exported() => false;
                    optional() => false;
                    dependencies() => null;
                    exclusions => null;
                    moduleScope() => null;
                    artifact() => null;
                    repositoryDisplayString() => null;
                    filter() => null;
                    repository() => null;
                });
            }
        }
        catch (e) {
            e.printStackTrace();
        }
    }

}
