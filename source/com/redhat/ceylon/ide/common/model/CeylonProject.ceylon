import ceylon.collection {
    MutableMap
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.cmr.api {
    RepositoryManager,
    Overrides,
    ArtifactContext,
    ArtifactCallback
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils {
        CeylonRepoManagerBuilder
    }
}
import com.redhat.ceylon.common {
    Constants,
    FileUtil,
    Backend
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker,
    TypeCheckerBuilder
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleValidator
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits,
    PhasedUnit,
    Context
}
import com.redhat.ceylon.compiler.typechecker.util {
    ModuleManagerFactory
}
import com.redhat.ceylon.ide.common.model.parsing {
    RootFolderScanner,
    ModulesScanner,
    ProjectFilesScanner
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast,
    toJavaStringList,
    BaseProgressMonitor,
    ImmutableMapWrapper,
    BaseProgressMonitorChild
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    BaseFolderVirtualFile,
    BaseFileVirtualFile,
    FileVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.launcher {
    Bootstrap
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult
}
import com.redhat.ceylon.model.typechecker.model {
    TypecheckerModules=Modules,
    Package,
    Module,
    ModelUtil
}
import com.redhat.ceylon.tools.bootstrap {
    CeylonBootstrapTool
}

import java.io {
    File,
    IOException
}
import java.lang {
    InterruptedException,
    RuntimeException,
    IllegalStateException,
    ObjectArray,
    ByteArray
}
import java.lang.ref {
    WeakReference
}
import java.util.concurrent {
    TimeUnit
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    ReadWriteLock,
    Lock,
    ReentrantLock
}

import org.xml.sax {
    SAXParseException
}
import java.net {
    URI
}
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    VfsServicesConsumer,
    ModelServicesConsumer
}

shared final class ProjectState
        of missing | parsing | parsed | typechecking | typechecked | compiled
        satisfies Comparable<ProjectState> {
    Integer ordinal;
    shared new missing {ordinal=0;}
    shared new parsing {ordinal=1;}
    shared new parsed {ordinal=2;}
    shared new typechecking {ordinal=3;}
    shared new typechecked {ordinal=4;}
    shared new compiled {ordinal=5;}
    compare(ProjectState other) => 
            ordinal <=> other.ordinal;
    equals(Object that) =>
            if (is ProjectState that)
    then ordinal==that.ordinal
    else false;
}

shared abstract class BaseCeylonProject() {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    variable CeylonProjectConfig? ceylonConfig = null;
    variable CeylonIdeConfig? ideConfig = null;
    shared ReadWriteLock sourceModelLock =  ReentrantReadWriteLock();
    Lock repositoryManagerLock = ReentrantLock();
    variable RepositoryManager? _repositoryManager = null;
    
    shared ModuleDependencies moduleDependencies = ModuleDependencies();
    
    "TODO: should not be shared. Will be made unshared when the
     using methods will have been implemented in Ceylon"
    shared variable ProjectState state = ProjectState.missing;
    
    shared Boolean parsing => state == ProjectState.parsing;
    shared Boolean parsed => state >= ProjectState.parsed;
    shared Boolean typechecking => state == ProjectState.typechecking;
    shared Boolean typechecked => state >= ProjectState.typechecked;
    shared Boolean compiled => state >= ProjectState.compiled;
    
    shared formal BaseCeylonProjects model;
    shared formal String name;
    shared formal File rootDirectory;
    shared formal Boolean hasConfigFile;
    shared formal String systemRepository;
    shared formal void createOverridesProblemMarker(
        Exception theOverridesException, 
        File absoluteFile, 
        Integer overridesLine, 
        Integer overridesColumn);
    //TODO: Only here for compatibility with legacy code!
    //
    //      This should be removed, since the real entry point is the 
    //      [[PhasedUnits]] object
    //            
    //      The only interesting data contained in the [[TypeChecker]] is the
    //      [[phasedUnitsOfDependencies|TypeChecker.phasedUnitsOfDependencies]]. 
    //      But new they should be managed in a modular way in each [[IdeModule]] 
    //      object accessible from the [[PhasedUnits]]")
    shared variable TypeChecker? typechecker=null;
    
    shared formal void removeOverridesProblemMarker();

    function createRepositoryManager() {
        return object extends CeylonRepoManagerBuilder() {
            shared actual Overrides? getOverrides(String? path) {
                if (! path exists) {
                    removeOverridesProblemMarker();
                }
                return super.getOverrides(path);
            }
            
            shared actual Overrides? getOverrides(File absoluteFile) {
                variable Overrides? result = null;
                variable Exception? overridesException = null;
                variable Integer overridesLine = -1;
                variable Integer overridesColumn = -1;
                try {
                    result = super.getOverrides(absoluteFile);
                } catch(Overrides.InvalidOverrideException e) {
                    overridesException = e;
                    overridesLine = e.line;
                    overridesColumn = e.column;
                } catch(IllegalStateException e) {
                    Throwable? cause = e.cause;
                    if (is SAXParseException cause) {
                        value parseException =  cause;
                        overridesException = parseException;
                        overridesLine = parseException.lineNumber;
                        overridesColumn = parseException.columnNumber;
                    } else if (is Exception cause) {
                        overridesException = cause;
                    } else {
                        overridesException = e;
                    }
                } catch(Exception e) {
                    overridesException = e;
                }
                
                if (exists theOverridesException = overridesException) {
                    createOverridesProblemMarker(
                        theOverridesException, 
                        absoluteFile, 
                        overridesLine, 
                        overridesColumn);
                } else {
                    removeOverridesProblemMarker();
                }
                return result;
            }
        }.offline(configuration.offline)
                .cwd(rootDirectory)
                .systemRepo(systemRepository)
                .extraUserRepos(
                    toJavaStringList(
                        referencedCeylonProjects.map((p) 
                            => p.ceylonModulesOutputDirectory.absolutePath)))
                .logger(platformUtils.cmrLogger)
                .isJDKIncluded(true)
                .buildManager();
    }
    
    shared RepositoryManager repositoryManager {
        try {
            repositoryManagerLock.lock();
            if (exists theRepoManager=_repositoryManager) {
                return theRepoManager;
            } else {
                value newRepoManager = createRepositoryManager();
                _repositoryManager = newRepoManager;
                return newRepoManager;
            }
        } finally {
            repositoryManagerLock.unlock();
        }
        
    }

    shared void resetRepositoryManager() {
        try {
            repositoryManagerLock.lock();
            _repositoryManager = null;
        } finally {
            repositoryManagerLock.unlock();
        }
        
    }

    shared {PhasedUnit*} parsedUnits =>
            if (parsed,
                exists units=typechecker?.phasedUnits?.phasedUnits)
            then CeylonIterable(units)
            else {};
    
    shared CeylonProjectConfig configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }

    shared CeylonIdeConfig ideConfiguration {
        if (exists config = ideConfig) {
            return config;
        } else {
            value newConfig = CeylonIdeConfig(this);
            ideConfig = newConfig;
            return newConfig;
        }
    }
    
    

    "Returns:
     - [[true]] if no error occured while creating the ceylon bootstrap files,
     - [[false]] if the boostrap files already exist and [[force]] is [[false]],
     - An error message if an [[IOException]] occured during creation of the bootstrap files."
    shared Boolean|String createBootstrapFiles(File embeddedDistributionFolder, String ceylonVersion, Boolean force=false) {
        value bootstrapJar = File(File(embeddedDistributionFolder, "lib"), "ceylon-bootstrap.jar");
        if(! bootstrapJar.\iexists()) {
            return "The 'ceylon-bootstrap.jar' archive is not accessible in the 'lib' directory of the embedded Ceylon distribution";
        }

        value binDirectory = File(embeddedDistributionFolder, "bin");
        if(! binDirectory.\iexists()) {
            return "The 'bin' folder is not accessible in the embedded Ceylon distribution";
        }

        if (!force) {
            value scriptFile = FileUtil.applyCwd(rootDirectory, File("ceylonb"));
            value batFile = FileUtil.applyCwd(rootDirectory, File("ceylonb.bat"));
            value bootstrapDir = File(FileUtil.applyCwd(rootDirectory, File(Constants.\iCEYLON_CONFIG_DIR)), "bootstrap");
            value propsFile = File(bootstrapDir, Bootstrap.\iFILE_BOOTSTRAP_PROPERTIES);
            value jarFile = File(bootstrapDir, Bootstrap.\iFILE_BOOTSTRAP_JAR);
            if (scriptFile.\iexists() || batFile.\iexists() || propsFile.\iexists() || jarFile.\iexists()) {
                return false;
            }
        }
        try {
            CeylonBootstrapTool.setupBootstrap(rootDirectory, bootstrapJar, binDirectory, URI(ceylonVersion), null, null);
        } catch(IOException ioe) {
            return ioe.message;
        }
        return true;
    }

    shared String defaultCharset
            => configuration.encoding else defaultDefaultCharset;
    
    shared default String defaultDefaultCharset
            => "utf8";
    
    "Un-hide a previously hidden output folder in old Eclipse projects
     For other IDEs, do nothing"
    shared default void fixHiddenOutputFolder(String folderProjectRelativePath) => noop();
    shared formal void deleteOldOutputFolder(String folderProjectRelativePath);
    shared formal void createNewOutputFolder(String folderProjectRelativePath);
    shared formal void refreshConfigFile();
    
    shared formal Boolean synchronizedWithConfiguration;
    shared formal Boolean nativeProjectIsAccessible;
    shared formal Boolean compileToJs;
    shared formal Boolean compileToJava;

    value loadBinariesFirst => 
            "true".equals(process.propertyValue("ceylon.loadBinariesFirst") else "true");
    
    shared Boolean loadDependenciesFromModelLoaderFirst =>
            compileToJava && loadBinariesFirst;
    
    shared {String*} ceylonRepositories
            => let (c = configuration) c.projectLocalRepos
            .chain(c.globalLookupRepos)
            .chain(c.projectRemoteRepos)
            .chain(c.otherRemoteRepos);

    shared default Boolean isJavaLikeFileName(String fileName) =>
            fileName.endsWith(".java");
    
    shared formal {BaseCeylonProject*} referencedCeylonProjects;
    shared formal {BaseCeylonProject*} referencingCeylonProjects;

    shared File ceylonModulesOutputDirectory =>
            File(
        Path(rootDirectory.absolutePath)
                .append(configuration.outputRepoProjectRelativePath)
                .platformDependentString);
    
    shared default abstract class Modules() satisfies {BaseIdeModule*} {
        shared formal BaseIdeModule default;
        shared formal BaseIdeModule language;
        shared formal Package? javaLangPackage;        
        shared formal {BaseIdeModule*} fromProject;
        shared formal {BaseIdeModule*} external;
        
        shared default BaseIdeModuleManager manager {
            assert(exists units=typechecker?.phasedUnits,
                is BaseIdeModuleManager mm=units.moduleManager);
            return mm; 
        }
        
        shared default BaseIdeModuleSourceMapper sourceMapper {
            assert(exists units=typechecker?.phasedUnits,
                is BaseIdeModuleSourceMapper msm=units.moduleSourceMapper);
            return msm; 
        }
    }

    shared formal Modules? modules;

    shared default BaseIdeModelLoader? modelLoader => modules?.manager?.modelLoader;
    
    shared formal {BaseFolderVirtualFile*} sourceFolders;
    shared formal {BaseFolderVirtualFile*} resourceFolders;
    shared formal {BaseFolderVirtualFile*} rootFolders;
    shared formal {BaseFileVirtualFile*} projectFiles;
    
    "
     Allows synchronizing operations that involve the source-related
     Ceylon model, for example:
     - setting up the typechecker,
     - creating or typechecking PhasedUnits,
     - etc ...
     
     It's based on a ReentrantReadWriteLock.

     To avoid deadlock, it always takes a time limit,
     after which the it stops waiting for the source 
     model availability and throws a [[RuntimeException|java.lang::RuntimeException]] Exception.
     The thrown exception is the one produced by 
     [[IdeUtils.newOperationCanceledException|com.redhat.ceylon.ide.common.platform::IdeUtils.newOperationCanceledException]]
     "
    shared Return withSourceModel<Return>(Boolean readonly, Return() do, Integer waitForModelInSeconds=20) {
        try {
            value theLock = 
                    if (readonly) 
                    then sourceModelLock.readLock() 
                    else sourceModelLock.writeLock();
            if (theLock.tryLock(waitForModelInSeconds, TimeUnit.\iSECONDS)) {
                try {
                    return do();
                } finally {
                    theLock.unlock();
                }
            } else {
                throw platformUtils.newOperationCanceledException(
                    "The source model ``
                    if (readonly) then "read" else "write"
                    `` lock of project ``
                    name 
                    `` could not be acquired within ``
                    waitForModelInSeconds`` seconds");
            }
        } catch(InterruptedException ie) {
            throw platformUtils.newOperationCanceledException(
                "The thread was interrupted while waiting for the source model ``
                if (readonly) then "read" else "write"
                `` lock of project ``name``");
        } catch(Exception e) {
            if (is RuntimeException e) {
                throw e;
            } else {
                throw RuntimeException(e);
            }
        }
    }
}



shared abstract class CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProject()
        satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared MutableMap<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> projectFilesMap = 
            ImmutableMapWrapper<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();

    value sourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();
    value resourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();

    shared actual formal CeylonProjectsAlias model;
    shared formal NativeProject ideArtifact;
    
    shared actual abstract class Modules() 
            extends super.Modules() 
            satisfies {IdeModuleAlias*} {
        shared formal TypecheckerModules typecheckerModules;
        
        shared actual Iterator<IdeModuleAlias> iterator() => 
                typecheckerModules.listOfModules
                .toArray(ObjectArray<Module>(typecheckerModules.listOfModules.size()))
                .array.map((m) => unsafeCast<IdeModuleAlias>(m)).iterator();
        
        shared actual IdeModuleAlias default =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.defaultModule);
        
        shared actual IdeModuleAlias language =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.languageModule);
        
        shared actual Package? javaLangPackage =>
                find((m) => m.nameAsString == "java.base")
                    ?.getDirectPackage("java.lang");
        
        shared actual {IdeModuleAlias*} fromProject
                => filter((m) => m.isProjectModule);
        
        shared actual {IdeModuleAlias*} external
                => filter((m) => ! m.isProjectModule);
        
        shared actual IdeModuleManagerAlias manager
                => unsafeCast<IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.manager); 
        
        shared actual IdeModuleSourceMapperAlias sourceMapper
                => unsafeCast<IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.sourceMapper); 
    }
    
    shared actual Modules? modules =>
            if (exists tcMods = typechecker?.phasedUnits?.moduleManager?.modules)
            then 
                object extends Modules() {
                    typecheckerModules = tcMods;
                }
            else
                null;
    
    "Virtual folders of existing source folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} sourceFolders =>
            sourceFoldersMap.resetKeys(
                sourceNativeFolders, 
                (nativeFolder) => 
                        vfsServices.createVirtualFolder(nativeFolder, ideArtifact)).items;
    
    "Virtual folders of existing resource folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} resourceFolders =>
            resourceFoldersMap.resetKeys(
                resourceNativeFolders, 
                (nativeFolder) => 
                        vfsServices.createVirtualFolder(nativeFolder, ideArtifact)).items;

    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} rootFolders => 
            sourceFolders.chain(resourceFolders);

    shared FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolderFromNative(NativeFolder folder) => 
            sourceFoldersMap[folder] else resourceFoldersMap[folder];
    
    shared actual {FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} projectFiles => projectFilesMap.items;

    shared FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? projectFileFromNative(NativeFile file) => 
            projectFilesMap[file];
    
    shared {NativeFile*} projectNativeFiles => 
            projectFilesMap.keys;

    shared Boolean addFileToModel(NativeFile file) {
        value virtualFile = vfsServices.createVirtualFile(file, ideArtifact);
        value parentFolder = vfsServices.getParent(file);
        if (!exists parentFolder) {
            // the file is a direct child of the project: 
            //files directly under the project are not part of the project source files.
            return false;
        }
        
        if (! vfsServices.getRootPropertyForNativeFolder(this, parentFolder) exists) {
            if (exists grandParent=vfsServices.getParent(parentFolder)) {
                if (! addFolderToModel(parentFolder, grandParent)) {
                    return false;
                }
            } else {
                return false;
            }
        }
        
        projectFilesMap.remove(file);  // TODO : why don't we keep the virtualFile if it is there ?
        projectFilesMap.put(file, virtualFile);
        
        // TODO : add the delta element
        
        return true;
    }
    
    shared void removeFileFromModel(NativeFile file) {
        projectFilesMap.remove(file);
        // TODO : remove the properties on the corresponding NativeFile
        // TODO : add the delta element
    }
    
    shared Boolean addFolderToModel(NativeFolder folder, NativeFolder parent) {
        value parentVirtualFile = vfsServices.createVirtualFolder(parent, ideArtifact);
        Boolean addIfParentAlreadyAdded() {
            if (exists parentPkg = parentVirtualFile.ceylonPackage,
                exists root=parentVirtualFile.rootFolder,
                exists loader = modelLoader) {
                Package pkg = loader.findOrCreatePackage(parentPkg.\imodule, 
                    if (parentPkg.nameAsString.empty) 
                    then vfsServices.getShortName(folder) 
                    else ".".join {parentPkg.nameAsString, vfsServices.getShortName(folder)});
                vfsServices.setPackagePropertyForNativeFolder(this,folder, WeakReference(pkg));
                vfsServices.setRootPropertyForNativeFolder(this, folder, WeakReference(root));
                return true;
            }
            return false;
        }

        if (!addIfParentAlreadyAdded()) {
            if (exists grandParent=vfsServices.getParent(parent),
                addFolderToModel(parent, grandParent)) {
                return addIfParentAlreadyAdded();
            } else {
                return false;
            }
        }
        
        // TODO : for incremental module and package build support, manage the module and package here
        // (local step corresponding to the ModuleScanner and ProjectFilesScanner)

        // TODO : add the delta element
        return true;
    }

    "Existing source folders as read form the IDE native project"
    shared formal {NativeFolder*} sourceNativeFolders;
    "Existing resource folders as read form the IDE native project"
    shared formal {NativeFolder*} resourceNativeFolders;

    shared {NativeFolder*} rootNativeFolders =>
            sourceNativeFolders.chain(resourceNativeFolders);

    
    shared formal {NativeProject*} referencedNativeProjects(NativeProject nativeProject);
    shared formal {NativeProject*} referencingNativeProjects(NativeProject nativeProject);
    
    shared actual {CeylonProjectAlias*} referencedCeylonProjects =>
            referencedNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;

    shared actual {CeylonProjectAlias*} referencingCeylonProjects =>
            referencingNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;
    
    shared formal void scanRootFolder(RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile> scanner);
    
    shared Boolean isCompilable(NativeFile file) {
        if (isCeylon(file)) {
            return true;
        }
        if (isJava(file) && compileToJava) {
            return true;
        }
        if (isJavascript(file) && compileToJs) {
            return true;
        }
        return false;
    }
    
    shared default Boolean isCeylon(NativeFile file) => 
            vfsServices.getShortName(file).endsWith(".ceylon");
    
    shared default Boolean isJava(NativeFile file) =>
            isJavaLikeFileName(vfsServices.getShortName(file));
    
    shared default Boolean isJavascript(NativeFile file) =>
            vfsServices.getShortName(file).endsWith(".js");
    
    "TODO: make it unshared as soon as the calling method is also in CeylonProject"
    shared void scanFiles(BaseProgressMonitor monitor) {
        try (progress = monitor.Progress(10000, null)) {
            void scan(
                {FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>*} roots,
                RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile> scanner(FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> root)) {
                for (root in roots) {
                    if (progress.cancelled) {
                        throw platformUtils.newOperationCanceledException("");
                    }
                    scanRootFolder(scanner(root));
                }
            }
            
            // First scan all non-default source modules and attach the contained packages 
            scan (sourceFolders, (root) => 
                ModulesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, progress));
            
            // Then scan all source files
            scan (sourceFolders, (root) => 
                ProjectFilesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, true, projectFilesMap, progress));
            
            // Finally scan all resource files
            scan (resourceFolders, (root) => 
                ProjectFilesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, false, projectFilesMap, progress));
        }
    }

    shared formal ModuleManagerFactory moduleManagerFactory;
        
    shared default void parseCeylonModel(BaseProgressMonitor mon) => withSourceModel {
        readonly = false;
        waitForModelInSeconds = 20;
        do() => withCeylonModelCaching(() {
            try (progress = mon.Progress(113, "Setting up typechecker for project ``name``")) {
                state = ProjectState.parsing;
                typechecker = null;
                resetRepositoryManager();
                projectFilesMap.clear();
                moduleDependencies.reset();
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }
                
                value newTypechecker = TypeCheckerBuilder(model.vfs)
                        .verbose(false)
                        .moduleManagerFactory(moduleManagerFactory)
                        .setRepositoryManager(repositoryManager).typeChecker;
                typechecker = newTypechecker;
                PhasedUnits phasedUnits = newTypechecker.phasedUnits;
                
                value moduleManager = unsafeCast<IdeModuleManagerAlias>(phasedUnits.moduleManager);
                value moduleSourceMapper = unsafeCast<IdeModuleSourceMapperAlias>(phasedUnits.moduleSourceMapper);
                moduleManager.typeChecker = newTypechecker;
                moduleSourceMapper.typeChecker = newTypechecker;
                Context context = newTypechecker.context;
                BaseIdeModelLoader modelLoader = moduleManager.modelLoader;
                //Module defaultModule = context.modules.defaultModule;
                
                progress.worked(1);
                
                progress.subTask("parsing source files for project `` name ``");
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException();
                }
                
                phasedUnits.moduleManager.prepareForTypeChecking();
                
                scanFiles(progress.newChild(10));
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }
                modelLoader.setupSourceFileObjects(phasedUnits.phasedUnits);
                
                progress.worked(1);
                
                // Parsing of ALL units in the source folder should have been done
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }
                
                progress.subTask("determining module dependencies for `` name ``");
                
                phasedUnits.visitModules();
                
                //By now the language module version should be known (as local)
                //or we should use the default one.
                Module languageModule = context.modules.languageModule;
                if (! languageModule.version exists) {
                    languageModule.version = TypeChecker.\iLANGUAGE_MODULE_VERSION;
                }
                
                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }
                
                ModuleValidator moduleValidator = object extends ModuleValidator(context, phasedUnits) {
                    shared actual void executeExternalModulePhases() {}
                    
                    shared actual Exception catchIfPossible(Exception e) {
                        if (platformUtils.isOperationCanceledException(e)) {
                            throw e;
                        }
                        return e;
                    }
                };
                
                Integer maxModuleValidatorWork = 100000;
                try(validatorProgress = progress.newChild(100).Progress(maxModuleValidatorWork, null)) {
                    moduleValidator.setListener(object satisfies ModuleValidator.ProgressListener {
                        shared actual void retrievingModuleArtifact(Module _module, ArtifactContext artifactContext) {
                            Integer numberOfModulesNotAlreadySearched = moduleValidator.numberOfModulesNotAlreadySearched();
                            Integer totalNumberOfModules = numberOfModulesNotAlreadySearched + moduleValidator.numberOfModulesAlreadySearched();
                            Integer oneModuleWork = maxModuleValidatorWork / totalNumberOfModules;
                            Integer workRemaining = numberOfModulesNotAlreadySearched * oneModuleWork;
                            if(validatorProgress.cancelled) {
                                throw platformUtils.newOperationCanceledException("Interrupted the retrieving of module : " + _module.signature);
                            }
                            validatorProgress.updateRemainingWork(workRemaining);
                            artifactContext.callback = object satisfies ArtifactCallback {
                                late variable BaseProgressMonitor.Progress artifactProgress;
                                late variable Integer size;
                                variable Integer alreadyDownloaded = 0;
                                value messageBuilder = StringBuilder()
                                        .append("- downloading module ")
                                        .append(_module.signature)
                                        .appendCharacter(' ');
                                shared actual void start(String nodeFullPath, Integer size, String contentStore) {
                                    this.size = size;
                                    Integer ticks = if (size > 0) then size else 100000;
                                    artifactProgress = validatorProgress.newChild(oneModuleWork).Progress(ticks, null);
                                    if (! contentStore.empty) {
                                        messageBuilder.append("from ").append(contentStore);
                                    }
                                    artifactProgress.subTask(messageBuilder.string);
                                    if (artifactProgress.cancelled) {
                                        throw platformUtils.newOperationCanceledException("Interrupted the download of module : " + _module.signature);
                                    }
                                }
                                shared actual void read(ByteArray bytes, Integer length) {
                                    if (artifactProgress.cancelled) {
                                        throw platformUtils.newOperationCanceledException("Interrupted the download of module : " + _module.signature);
                                    }
                                    if (size < 0) {
                                        artifactProgress.updateRemainingWork(length*100);
                                    } else {
                                        artifactProgress.subTask("``messageBuilder.string`` (`` alreadyDownloaded * 100 / size ``% )");
                                    }
                                    alreadyDownloaded += length;
                                    artifactProgress.worked(length);
                                }
                                shared actual void error(File localFile, Throwable t) {
                                    localFile.delete();
                                    artifactProgress.destroy(null);
                                    if (is Exception t,
                                        platformUtils.isOperationCanceledException(t)) {
                                        throw t;
                                    }
                                }
                                shared actual void done(File file) =>
                                        artifactProgress.destroy(null);
                            };
                        }
                        
                        shared actual void resolvingModuleArtifact(Module _module,
                            ArtifactResult artifactResult) {
                            if (validatorProgress.cancelled) {
                                throw platformUtils.newOperationCanceledException("Interrupted the resolving of module : " + _module.signature);
                            }
                            Integer numberOfModulesNotAlreadySearched = moduleValidator.numberOfModulesNotAlreadySearched();
                            validatorProgress.updateRemainingWork(numberOfModulesNotAlreadySearched * 100
                                / (numberOfModulesNotAlreadySearched + moduleValidator.numberOfModulesAlreadySearched()));
                            validatorProgress.subTask("resolving module ``_module.signature``");
                        }
                        
                        retrievingModuleArtifactFailed(Module m, ArtifactContext ac) => noop();
                        retrievingModuleArtifactSuccess(Module m, ArtifactResult ar) => noop();
                    });
                    
                    moduleValidator.verifyModuleDependencyTree();
                }
                
                newTypechecker.phasedUnitsOfDependencies = moduleValidator.phasedUnitsOfDependencies;
                
                for (dependencyPhasedUnits in newTypechecker.phasedUnitsOfDependencies) {
                    modelLoader.addSourceArchivePhasedUnits(dependencyPhasedUnits.phasedUnits);
                }
                
                modelLoader.setModuleAndPackageUnits();
                
                if (compileToJs) {
                    for (_module in newTypechecker.context.modules.listOfModules) {
                        if (is BaseIdeModule _module) {
                            if (_module.isCeylonArchive
                                && ModelUtil.isForBackend(_module.nativeBackends, Backend.\iJavaScript.asSet())) {
                                value importedModuleImports = 
                                        CeylonIterable(moduleSourceMapper.retrieveModuleImports(_module))
                                        .filter((moduleImport) => 
                                    ModelUtil.isForBackend(moduleImport.nativeBackends, Backend.\iJavaScript.asSet()))
                                        .sequence();
                                if (nonempty importedModuleImports) {
                                    File? artifact = repositoryManager.getArtifact(
                                        ArtifactContext(
                                            _module.nameAsString, 
                                            _module.version, 
                                            ArtifactContext.\iJS));
                                    if (artifact is Null) {
                                        for (importInError in importedModuleImports) {
                                            moduleSourceMapper.attachErrorToModuleImport(importInError, 
                                                "module not available for JavaScript platform: '``_module.nameAsString``' \"``_module.version``\"");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                moduleDependencies.addModulesWithDependencies(newTypechecker.context.modules.listOfModules);
                
                progress.worked(1);
                
                state = ProjectState.parsed;
                
                completeCeylonModelParsing(progress.newChild(10));
                
                model.modelParsed(this);
            }
        });
    };
    
    shared formal void completeCeylonModelParsing(BaseProgressMonitorChild monitor);
}

