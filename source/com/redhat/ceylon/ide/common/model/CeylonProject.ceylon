import ceylon.collection {
    MutableMap
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
import com.redhat.ceylon.cmr.impl {
    NpmRepository
}
import com.redhat.ceylon.cmr.spi {
    ContentStore
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
    ModuleValidator,
    Warning
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
import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    VfsServicesConsumer,
    ModelServicesConsumer,
    Status
}
import com.redhat.ceylon.ide.common.typechecker {
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast,
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
    Types {
        nativeString
    },
    InterruptedException,
    RuntimeException,
    IllegalStateException,
    ByteArray,
    System,
    overloaded
}
import java.lang.ref {
    WeakReference,
    SoftReference
}
import java.net {
    URI
}
import java.util {
    WeakHashMap,
    EnumSet,
    Arrays
}
import java.util.concurrent {
    TimeUnit
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    Lock,
    ReentrantLock
}

import org.xml.sax {
    SAXParseException
}

shared final class ProjectState
        of missing
         | parsing
         | parsed
         | typechecking
         | typechecked
         | compiled
        satisfies Comparable<ProjectState> {
    Integer ordinal;
    shared new missing { ordinal=0; }
    shared new parsing { ordinal=1; }
    shared new parsed { ordinal=2; }
    shared new typechecking { ordinal=3; }
    shared new typechecked { ordinal=4; }
    shared new compiled { ordinal=5; }
    compare(ProjectState other) =>
            ordinal <=> other.ordinal;
    equals(Object that) =>
            if (is ProjectState that)
            then ordinal==that.ordinal
            else false;
}

EnumSet<Warning> allWarnings = EnumSet.allOf(`Warning`);

shared abstract class BaseCeylonProject() {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    variable CeylonProjectConfig? ceylonConfig = null;
    variable CeylonIdeConfig? ideConfig = null;
    shared ReentrantReadWriteLock sourceModelLock =  ReentrantReadWriteLock();
    Lock repositoryManagerLock = ReentrantLock();
    variable RepositoryManager? _repositoryManager = null;

    shared ModuleDependencies moduleDependencies = ModuleDependencies();

    value contentStoreClass => `ContentStore`;

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
    //      But now they should be managed in a modular way in each [[IdeModule]] 
    //      object accessible from the [[PhasedUnits]]")
    shared variable TypeChecker? typechecker=null;

    shared formal void removeOverridesProblemMarker();

	shared CeylonRepoManagerBuilder newRepositoryManagerBuilder(Boolean withOutput = false) {
		value builder = object extends CeylonRepoManagerBuilder() {
            overloaded
            shared actual Overrides? getOverrides(String? path) {
				if (! path exists) {
					removeOverridesProblemMarker();
				}
				return super.getOverrides(path);
			}
            overloaded
            shared actual Overrides? getOverrides(File absoluteFile) {
				variable Overrides? result = null;
				variable Exception? overridesException = null;
				variable Integer overridesLine = -1;
				variable Integer overridesColumn = -1;
				try {
					result = super.getOverrides(absoluteFile);
				}
                catch(Overrides.InvalidOverrideException e) {
					overridesException = e;
					overridesLine = e.line;
					overridesColumn = e.column;
				}
                catch(IllegalStateException e) {
					switch (cause = e.cause)
                    case (is SAXParseException) {
						value parseException =  cause;
						overridesException = parseException;
						overridesLine = parseException.lineNumber;
						overridesColumn = parseException.columnNumber;
					}
                    else case (is Exception) {
						overridesException = cause;
					}
                    else {
						overridesException = e;
					}
				}
                catch(Exception e) {
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
		.extraUserRepos(Arrays.asList(
			for (p in referencedCeylonProjects)
			nativeString(p.ceylonModulesOutputDirectory.absolutePath)))
		.logger(platformUtils.cmrLogger)
		.isJDKIncluded(true);
		if (withOutput) {
			builder.outRepo(configuration.outputRepo);
		}
		return builder;
	}

    function createRepositoryManager() {
        value manager = newRepositoryManagerBuilder().buildManager();
        for (repo in manager.repositories) {
            if (is NpmRepository repo) {
                value npmCommand = ideConfiguration.npmPath;
                String? pathForRunningNpm;
                if (exists nodeCommand = ideConfiguration.nodePath) {
                    String nodeDirectory = File(nodeCommand).parentFile.absolutePath;
                    {String+}? oldPathElements;
                    for (entry in System.getenv().entrySet()) {
                        if (entry.key.string.equalsIgnoringCase("PATH")) {
                            oldPathElements = entry.\ivalue.string.split(File.pathSeparatorChar.equals, true, true);
                            break;
                        }
                    }
                    else {
                        oldPathElements = null;
                    }
                    pathForRunningNpm = 
                        if (exists oldPathElements)
                        then File.pathSeparator.join(
                            if (nodeDirectory in oldPathElements)
                            then oldPathElements
                            else { nodeDirectory, *oldPathElements })
                        else nodeDirectory;
                } else {
                    pathForRunningNpm = null;
                }
                repo.setNpmCommand(npmCommand); 
                repo.setPathForRunningNpm(pathForRunningNpm); 
            }
        }
        return manager;
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

    shared default void resetRepositoryManager() {
        try {
            repositoryManagerLock.lock();
            _repositoryManager = null;
        } finally {
            repositoryManagerLock.unlock();
        }

    }

    shared default {PhasedUnit*} parsedUnits => {
            if (parsed, exists units = typechecker?.phasedUnits?.phasedUnits)
            for (unit in units) unit
        };

    shared default PhasedUnit? getParsedUnit(BaseFileVirtualFile virtualFile) =>
            if (parsed,
                exists phasedUnits=typechecker?.phasedUnits)
            then phasedUnits.getPhasedUnit(virtualFile)
            else null;

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

    shared Boolean showWarnings =>
            configuration.suppressWarningsEnum != allWarnings;

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

        value scriptFile = FileUtil.applyCwd(rootDirectory, File("ceylonb"));
        value batFile = FileUtil.applyCwd(rootDirectory, File("ceylonb.bat"));
        if (!force) {
            value bootstrapDir = File(FileUtil.applyCwd(rootDirectory, File(Constants.ceylonConfigDir)), "bootstrap");
            value propsFile = File(bootstrapDir, Bootstrap.fileBootstrapProperties);
            value jarFile = File(bootstrapDir, Bootstrap.fileBootstrapJar);
            if (scriptFile.\iexists() || batFile.\iexists() || propsFile.\iexists() || jarFile.\iexists()) {
                return false;
            }
        }
        try {
            CeylonBootstrapTool.setupBootstrap(rootDirectory, bootstrapJar, binDirectory, URI(ceylonVersion), null, null);
        } catch(IOException ioe) {
            return ioe.message;
        }
        
        try {
            scriptFile.setExecutable(true);
            batFile.setExecutable(true);
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
    shared formal void refreshConfigFile(String projectRelativePath);

    shared formal Boolean synchronizedWithConfiguration;
    shared formal Boolean nativeProjectIsAccessible;
    shared formal Boolean compileToJs;
    shared formal Boolean compileToJava;

    shared default Boolean loadBinariesFirst =>
            true.string == (process.propertyValue("ceylon.loadBinariesFirst") else true.string);

    shared Boolean loadDependenciesFromModelLoaderFirst =>
            compileToJava && loadBinariesFirst;

    shared default Boolean loadInterProjectDependenciesFromSourcesFirst => false;

    shared {String*} ceylonRepositories
            => let (c = configuration)
                c.projectLocalRepos
                 .chain(c.globalLookupRepos)
                 .chain(c.projectRemoteRepos)
                 .chain(c.otherRemoteRepos);

    shared {File*} ceylonRepositoryBaseDirectories =>
            { for (repo in repositoryManager.repositories)
              if (exists contentStore = repo.root.getService(contentStoreClass))
              for (dir in contentStore.baseDirectories)
              dir };

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
            if (theLock.tryLock(waitForModelInSeconds, TimeUnit.seconds)) {
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

shared alias AnyCeylonProject => CeylonProject<out Anything, out Anything, out Anything, out Anything>;

shared abstract class CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProject()
        satisfies ChangeAware<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
                & VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
given NativeProject satisfies Object
given NativeResource satisfies Object
given NativeFolder satisfies NativeResource
given NativeFile satisfies NativeResource {
    shared MutableMap<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> projectFilesMap =
            ImmutableMapWrapper<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>(emptyMap, map);

    value sourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFileAlias>(emptyMap, map);
    value resourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFileAlias>(emptyMap, map);

    value virtualFolderCache = WeakHashMap<NativeFolder, SoftReference<FolderVirtualFileAlias>>();
    value virtualFileCache = WeakHashMap<NativeFile, SoftReference<FileVirtualFileAlias>>();
    // value virtualFolderCacheLock = ReentrantReadWriteLock();

    variable CeylonProjectBuildAlias? build_ = null;

    shared actual formal CeylonProjectsAlias model;
    shared formal NativeProject ideArtifact;

    shared CeylonProjectBuildAlias build {
        if (exists build=build_) {
            return build;
        }
        value build = CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>(this);
        build_ = build;
        return build;
    }

    shared actual default void resetRepositoryManager() {
        super.resetRepositoryManager();
        buildHooks.each((hook) => hook.repositoryManagerReset(this));
    }

    nativeProjectIsAccessible => modelServices.nativeProjectIsAccessible(ideArtifact);

    shared actual abstract class Modules()
            extends super.Modules()
            satisfies {IdeModuleAlias*} {
        shared formal TypecheckerModules typecheckerModules;

        shared actual Iterator<IdeModuleAlias> iterator() =>
                [ for (m in typecheckerModules.listOfModules)
                  unsafeCast<IdeModuleAlias>(m) ]
                    .iterator();

        shared actual IdeModuleAlias default =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.defaultModule);

        shared actual IdeModuleAlias language =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.languageModule);

        javaLangPackage =>
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
                vfsServices.createVirtualFolder(nativeFolder, ideArtifact), true).items;

    "Virtual folders of existing resource folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} resourceFolders =>
            resourceFoldersMap.resetKeys(
                resourceNativeFolders,
                (nativeFolder) =>
                vfsServices.createVirtualFolder(nativeFolder, ideArtifact), true).items;

    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} rootFolders =>
            sourceFolders.chain(resourceFolders);

    shared FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolderFromNative(NativeFolder folder) =>
            sourceFoldersMap[folder] else resourceFoldersMap[folder];

    shared actual {FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} projectFiles => projectFilesMap.items;

    shared FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? projectFileFromNative(NativeFile file) =>
            projectFilesMap[file];

    shared {NativeFile*} projectNativeFiles =>
            projectFilesMap.keys;

    shared actual {ProjectPhasedUnitAlias*} parsedUnits =>
            super.parsedUnits.map((pu) => unsafeCast<ProjectPhasedUnitAlias>(pu));

    shared actual ProjectPhasedUnitAlias? getParsedUnit(BaseFileVirtualFile virtualFile) =>
            unsafeCast<ProjectPhasedUnitAlias?>(super.getParsedUnit(virtualFile));

    "Returns the [[FileVirtualFileAlias]] added to the model,
     or [[null]] if it could not be added"
    shared FileVirtualFileAlias? addFileToModel(NativeFile file) {
        value parentFolder = vfsServices.getParent(file);
        if (!exists parentFolder) {
            // the file is a direct child of the project: 
            //files directly under the project are not part of the project source files.
            return null;
        }

        if (! vfsServices.getRootPropertyForNativeFolder(this, parentFolder) exists &&
        ! addFolderToModel(parentFolder) exists) {
            return null;
        }

        projectFilesMap.remove(file);  // TODO : why don't we keep the virtualFile if it is there ?
        value virtualFile = vfsServices.createVirtualFile(file, ideArtifact);
        projectFilesMap[file] = virtualFile;
        return virtualFile;
    }


    shared void removeFileFromModel(NativeFile file) {
        projectFilesMap.remove(file);
    }

    shared FolderVirtualFileAlias? addFolderToModel(NativeFolder folder) {
        NativeFolder? parent = vfsServices.getParent(folder);
        if (!exists parent) {
            return null;
        }

        value parentVirtualFile = vfsServices.createVirtualFolder(parent, ideArtifact);
        FolderVirtualFileAlias? addIfParentAlreadyAdded() {
            if (exists parentPkg = parentVirtualFile.ceylonPackage,
                exists root=parentVirtualFile.rootFolder,
                exists loader = modelLoader) {
                Package pkg = loader.findOrCreatePackage(parentPkg.\imodule,
                    if (parentPkg.nameAsString.empty)
                    then vfsServices.getShortName(folder)
                    else ".".join {parentPkg.nameAsString, vfsServices.getShortName(folder)});
                vfsServices.setPackagePropertyForNativeFolder(this,folder, WeakReference(pkg));
                vfsServices.setRootPropertyForNativeFolder(this, folder, WeakReference(root));
                return vfsServices.createVirtualFolder(folder, ideArtifact);
            }
            return null;
        }

        FolderVirtualFileAlias addedVirtualFolder;
        if (exists added = addIfParentAlreadyAdded()) {
            addedVirtualFolder = added;
        } else {
            if (addFolderToModel(parent) exists) {
                if (exists added = addIfParentAlreadyAdded()) {
                    addedVirtualFolder = added;
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }

        // TODO : for incremental module and package build support, manage the module and package here
        // (local step corresponding to the ModuleScanner and ProjectFilesScanner)

        // TODO : add the delta element
        return addedVirtualFolder;
    }

    shared void removeFolderFromModel(NativeFolder folder) {
        void removeProperty(String propertyName,
                void remove(CeylonProjectAlias cpa, NativeFolder nf))  {
            try {
                remove(this, folder);
            } catch (e) {
                platformUtils.log(
                    Status._WARNING,
                    "``propertyName`` property could not be removed from native folder : ``
                    vfsServices.getVirtualFilePathString(folder)``", e);
            }
        }
        removeProperty("Package", vfsServices.removePackagePropertyForNativeFolder);
        removeProperty("Root", vfsServices.removeRootPropertyForNativeFolder);
        removeProperty("RootIsSource", vfsServices.removeRootIsSourceProperty);
    }

    "Existing source folders as read from the IDE native project"
    shared {NativeFolder*} sourceNativeFolders =>
            modelServices.sourceNativeFolders(this);

    "Existing resource folders as read from the IDE native project"
    shared {NativeFolder*} resourceNativeFolders =>
            modelServices.resourceNativeFolders(this);

    shared {NativeFolder*} rootNativeFolders =>
            sourceNativeFolders.chain(resourceNativeFolders);

    shared actual {CeylonProjectAlias*} referencedCeylonProjects =>
            modelServices.referencedNativeProjects(ideArtifact)
                .map((nativeProject) => model.getProject(nativeProject))
                .coalesced;

    shared actual {CeylonProjectAlias*} referencingCeylonProjects =>
            modelServices.referencingNativeProjects(ideArtifact)
                .map((nativeProject) => model.getProject(nativeProject))
                .coalesced;

    shared Boolean isCompilable(NativeFile file)
            => isCeylon(file)
            || isJava(file) && compileToJava
            || isJavascript(file) && compileToJs;

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
                    modelServices.scanRootFolder(scanner(root));
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

                if (exists jdkProvider = configuration.jdkProvider) {
                    value [name, *rest] = jdkProvider.split('/'.equals).sequence();
                    if (exists version = rest[0],
                        exists file = repositoryManager.getArtifact(
                            ArtifactContext(null, name, version, ArtifactContext.jar))) {

                        // OK
                    } else {
                        throw platformUtils.newOperationCanceledException(
                            "JDK provider not found in repository: " + jdkProvider);
                    }
                }
                value moduleSourceMapper = unsafeCast<IdeModuleSourceMapperAlias>(phasedUnits.moduleSourceMapper);
                moduleManager.typeChecker = newTypechecker;
                moduleSourceMapper.typeChecker = newTypechecker;
                Context context = newTypechecker.context;
                value modelLoader = moduleManager.modelLoader;
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
                    languageModule.version = TypeChecker.languageModuleVersion;
                }

                if (progress.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }

                object moduleValidator extends ModuleValidator(context, phasedUnits) {
                    shared actual void executeExternalModulePhases() {}

                    shared actual Exception catchIfPossible(Exception e) {
                        if (platformUtils.isOperationCanceledException(e)) {
                            throw e;
                        }
                        return e;
                    }
                }

                Integer maxModuleValidatorWork = 100000;
                try(validatorProgress = progress.newChild(100).Progress(maxModuleValidatorWork, null)) {
                    moduleValidator.setListener(object satisfies ModuleValidator.ProgressListener {
                        shared actual void retrievingModuleArtifact(Module _module, ArtifactContext artifactContext) {
                            Integer numberOfModulesNotAlreadySearched = moduleValidator.numberOfModulesNotAlreadySearched();
                            Integer totalNumberOfModules = numberOfModulesNotAlreadySearched + moduleValidator.numberOfModulesAlreadySearched();
                            Integer oneModuleWork = maxModuleValidatorWork / totalNumberOfModules;
                            Integer workRemaining = numberOfModulesNotAlreadySearched * oneModuleWork;
                            if(validatorProgress.cancelled) {
                                throw platformUtils.newOperationCanceledException("Interrupted the retrieval of module : " + _module.signature);
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
                                done(File file) => artifactProgress.destroy(null);
                            };
                        }

                        shared actual void resolvingModuleArtifact(Module _module,
                                ArtifactResult artifactResult) {
                            if (validatorProgress.cancelled) {
                                throw platformUtils.newOperationCanceledException("Interrupted the resolution of module : " + _module.signature);
                            }
                            Integer numberOfModulesNotAlreadySearched = moduleValidator.numberOfModulesNotAlreadySearched();
                            validatorProgress.updateRemainingWork(numberOfModulesNotAlreadySearched * 100
                            / (numberOfModulesNotAlreadySearched + moduleValidator.numberOfModulesAlreadySearched()));
                            validatorProgress.subTask("Resolving module ``_module.signature``");
                        }

                        retrievingModuleArtifactFailed(Module m, ArtifactContext ac) => noop();
                        retrievingModuleArtifactSuccess(Module m, ArtifactResult ar) => noop();
                    });

                    buildHooks.each((hook) => hook.beforeDependencyTreeValidation(this, progress));
                    moduleValidator.verifyModuleDependencyTree();
                    buildHooks.each((hook) => hook.afterDependencyTreeValidation(this, progress));
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
                            && ModelUtil.isForBackend(_module.nativeBackends, Backend.javaScript.asSet())) {
                                value importedModuleImports =
                                        [ for (moduleImport in moduleSourceMapper.retrieveModuleImports(_module))
                                           if (ModelUtil.isForBackend(moduleImport.nativeBackends, Backend.javaScript.asSet()))
                                           moduleImport ];
                                if (nonempty importedModuleImports) {
                                    File? artifact = repositoryManager.getArtifact(
                                        ArtifactContext(
                                            null,
                                            _module.nameAsString,
                                            _module.version,
                                            ArtifactContext.js));
                                    if (!exists artifact) {
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

                model.ceylonModelParsed(this);
            }
        });
    };

    shared FileVirtualFileAlias getOrCreateFileVirtualFile(NativeFile nativeFile) {
        if (exists existingFile=projectFilesMap.get(nativeFile)) {
            return existingFile;
        }
        else {
            if (exists virtualFile=virtualFileCache.get(nativeFile)?.get()) {
                return virtualFile;
            }
            value virtualFile = vfsServices.createVirtualFile(nativeFile, ideArtifact);
            virtualFileCache[virtualFile.nativeResource] = SoftReference(virtualFile);
            return virtualFile;
        }
    }


    shared FolderVirtualFileAlias getOrCreateFolderVirtualFile(NativeFolder nativeFolder) {
        if (exists virtualFile=virtualFolderCache.get(nativeFolder)?.get()) {
            return virtualFile;
        }
        value virtualFile = vfsServices.createVirtualFolder(nativeFolder, ideArtifact);
        virtualFolderCache[virtualFile.nativeResource] = SoftReference(virtualFile);
        return virtualFile;
    }

    shared Boolean isFileInSourceFolder(NativeFile file) =>
            isFileInRootFolder(file, true);

    shared Boolean isFileInResourceFolder(NativeFile file) =>
            isFileInRootFolder(file, false);

    Boolean isFileInRootFolder(NativeFile file, Boolean? sourceRoot=null) {
        if (exists parentFolder = vfsServices.getParent(file)) {
            return isFolderInRootFolder(parentFolder, sourceRoot);
        }
        return false;
    }

    Boolean isFolderInRootFolder(NativeFolder folder, Boolean? sourceRoot=null) {
        if (exists rootIsSource = vfsServices.getRootIsSourceProperty(this, folder)) {
            return if (exists sourceRoot) then sourceRoot == rootIsSource else true;
        }
        return vfsServices.isDescendantOfAny(folder,
            if (exists sourceRoot)
            then
            if (sourceRoot)
            then sourceNativeFolders
            else resourceNativeFolders
            else rootNativeFolders);
    }

    shared Boolean isResourceForModel(NativeResource resource) {
        if (!vfsServices.isFolder(resource),
            is NativeFile file=resource) {
            return isSourceFile(file)
                || isResourceFile(file);
        }
        else {
            assert(is NativeFolder resource);
            return isFolderInRootFolder(resource);
        }
    }

    shared Boolean isSourceFile(NativeFile file) =>
            isFileInSourceFolder(file) && isCompilable(file);

    shared Boolean isResourceFile(NativeFile file) =>
            isFileInResourceFolder(file); // TODO: add the constraint that it should be in the right packages ?

    "This iterable contains resources that need an additional action to be fully visible
     during the model update (for example flushing the contents to the disk or
     refreshing a configuration).

     If the action cannot not be done, they will not be fully visible and should be removed
     from the changed resources submitted to the model update."
    value shouldBeMadeFullyVisibleBeforeModelUpdate => {

        if (exists configResource =
                vfsServices.fromJavaFile(
                    configuration.projectConfigFile, ideArtifact))
        then configResource -> (() {
            if (vfsServices.flushIfNecessary(configResource)) {
                configuration.refresh();
                return true;
            } else {
                return false;
            }
        })
        else null,

        if (exists ideConfigResource =
                vfsServices.fromJavaFile(
                    ideConfiguration.ideConfigFile, ideArtifact))
        then ideConfigResource -> (() {
            if (vfsServices.flushIfNecessary(ideConfigResource)) {
                ideConfiguration.refresh();
                return true;
            } else {
                return false;
            }
        })
        else null,

        if (exists overridesFilePath
                = configuration.overrides,
            exists overridesFile
                = FileUtil.absoluteFile(
                    FileUtil.applyCwd(rootDirectory, File(overridesFilePath))),
            exists overridesResource
                = vfsServices.fromJavaFile(overridesFile, ideArtifact))
        then overridesResource -> (() => vfsServices.flushIfNecessary(overridesResource))
        else null

    }.coalesced;

    shared void projectFileTreeChanged({NativeResourceChange*} projectFileChanges) {

        ChangeToConvert updateModelAndConvertToProjectFileChange(NativeResourceChange nativeChange) {
            switch (nativeChange)
            case(is NativeFileChange) {
                function convertToVirtualFile(NativeFile file) {
                    switch(nativeChange)
                    case(is NativeFileContentChange) {
                        return getOrCreateFileVirtualFile(file);
                    }
                    case(is NativeFileAddition) {
                        return addFileToModel(file);
                    }
                    case(is NativeFileRemoval) {
                        value removedFile = getOrCreateFileVirtualFile(file);
                        removeFileFromModel(file);
                        return removedFile;
                    }
                }
                return [nativeChange, convertToVirtualFile];
            }
            case(is NativeFolderChange) {
                function convertToVirtualFile(NativeFolder folder) {
                    switch(nativeChange)
                    case (is NativeFolderAddition) {
                        if(vfsServices.existsOnDisk(folder)) {
                            return addFolderToModel(folder);
                        } else {
                            return null;
                        }
                    }
                    case (is NativeFolderRemoval) {
                        value removedFolder = getOrCreateFolderVirtualFile(folder);
                        removeFolderFromModel(folder);
                        return removedFolder;
                    }
                }
                return [nativeChange, convertToVirtualFile];
            }
        }

        value shouldBeMadeFullyVisible = map(shouldBeMadeFullyVisibleBeforeModelUpdate);

        function changeFullyVisible(NativeResourceChange change)
                => if (exists actionToMakeItVisible = shouldBeMadeFullyVisible[change.resource])
                then actionToMakeItVisible()
                else true;

        function changeAndArtifact(NativeResourceChange change)
                => if (isResourceForModel(change.resource),
                       exists projectFileChange
                           = model.toProjectChange(updateModelAndConvertToProjectFileChange(change)))
                then projectFileChange
                else [change, ideArtifact];

        build.fileTreeChanged(
            projectFileChanges
                .filter(changeFullyVisible)
                .map(changeAndArtifact));

        for (referencingProject in referencingCeylonProjects) {
            referencingProject.referencedProjectFileTreeChanged(this, projectFileChanges);
        }
        // Positionner le full-build, etc ... + quelque chose à builder en fonction des change events (aussi des changements de binaires, d'overrides.xml, etc ...)
        // Ajouter des changements dans le sourceChangeEvent du CeylonProjectBuild (seulement sur les sources qui font partie des root folders de moi ou des projets référencés) (=> créer les ResourceVirtualFileChange)
        // Ajouter les changements dans tous les projets qui me référencent
    }

    shared void referencedProjectFileTreeChanged(CeylonProjectAlias referencedProject, {NativeResourceChange*} changesInReferencedProject) {
        function convertToProjectFileChange(NativeResourceChange nativeChange) {
            switch (nativeChange)
            case(is NativeFileChange) {
                return [nativeChange, referencedProject.getOrCreateFileVirtualFile];
            }
            case(is NativeFolderChange) {
                return [nativeChange, referencedProject.getOrCreateFolderVirtualFile];
            }
        }

        build.fileTreeChanged(changesInReferencedProject.map((nativeChange) =>
        if (referencedProject.isResourceForModel(nativeChange.resource),
            exists projectFileChange=model.toProjectChange(convertToProjectFileChange(nativeChange)))
        then projectFileChange
        else [nativeChange, referencedProject.ideArtifact]));
    }

    shared formal void completeCeylonModelParsing(BaseProgressMonitorChild monitor);

    shared default {BuildHookAlias*} buildHooks => {};

    string => ideArtifact.string;
}

