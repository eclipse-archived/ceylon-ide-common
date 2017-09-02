import ceylon.collection {
    naturalOrderTreeSet,
    SortedSet,
    HashSet
}

import com.redhat.ceylon.cmr.api {
    ModuleSearchResult {
        ModuleDetails
    },
    ModuleVersionDetails
}
import com.redhat.ceylon.cmr.impl {
    DefaultRepository,
    JDKRepository
}
import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    VisitorAdaptor
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    LinkedMode
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
    moduleQueries,
    nodes
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

import java.lang {
    Types {
        nativeString
    },
    JInteger=Integer
}

SortedSet<String> sortedJdkModuleNames
        = naturalOrderTreeSet {
            for (name in JDKUtils.jdkModuleNames)
            name.string
        };

shared interface ModuleCompletion {

    function isImplicitNamespace(String ns)
            => ns in [DefaultRepository.\iNAMESPACE, JDKRepository.\iNAMESPACE];

    shared void addModuleCompletions(CompletionContext ctx, Integer offset,
        String prefix, Tree.ImportPath? path, Node node, 
        Boolean withBody, BaseProgressMonitor monitor,
        Boolean addNamespaceProposals = true) {
        
        value fp = fullPath(offset, prefix, path);

        variable Tree.ImportModule? im = null;
        object moduleImportVisitor extends VisitorAdaptor() {
            shared actual void visitImportModule(Tree.ImportModule that) {
                super.visitImportModule(that);
                if (exists path = that.importPath, path == node) {
                    im = that;
                }
            }
        }

        moduleImportVisitor.visit(ctx.parsedRootNode);

        value existingNamespace = im?.namespace?.text;

        if (!existingNamespace exists && addNamespaceProposals) {
            addNamespaceCompletions(ctx, offset, prefix);
        }

        addModuleCompletionsInternal {
            offset = offset;
            prefix = prefix;
            node = node;
            len = fp.size;
            pfp = fp + prefix;
            ctx = ctx;
            withBody = withBody;
            monitor = monitor;
            namespace = existingNamespace;
        };
    }

    shared void addNamespaceCompletions(CompletionContext ctx, Integer offset, String prefix,
        Boolean addColon = true) {
        value namespaces = HashSet<String>();

        for (repo in ctx.typeChecker.context.repositoryManager.repositories) {
            if (exists ns = repo.namespace,
                !isImplicitNamespace(ns),
                ns.startsWith(prefix)) {
                namespaces.add(ns);
            }
        }

        for (ns in namespaces) {
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                icon = Icons.modules;
                description = ns + (addColon then ":" else "");
            };
        }
    }

    void addModuleCompletionsInternal(Integer offset, String prefix, Node node,
        Integer len, String pfp, CompletionContext ctx, Boolean withBody,
        BaseProgressMonitor monitor, String? namespace) {
        
        try (progress = monitor.Progress(1, null)) {
            if (pfp.startsWith("java.")) {
                for (name in sortedJdkModuleNames) {
                    if (name.startsWith(pfp),
                        !moduleAlreadyImported(ctx, name)) {
                        
                        platformServices.completion.newJDKModuleProposal {
                            ctx = ctx;
                            offset = offset;
                            prefix = prefix;
                            len = len;
                            versioned = getModuleString {
                                withBody = withBody;
                                name = name;
                                version = JDKUtils.jdk.version;
                            };
                            name = name;
                        };
                    }
                }
            }
            else {
                progress.subTask("querying module repositories...");
                value query = moduleQueries.getModuleQuery {
                    prefix = pfp;
                    mod = ctx.lastPhasedUnit.\ipackage.\imodule;
                    project = ctx.ceylonProject;
                    namespace = namespace;
                };

                query.jvmBinaryMajor = JInteger(Versions.jvmBinaryMajorVersion);
                query.jvmBinaryMinor = JInteger(Versions.jvmBinaryMinorVersion);
                query.jsBinaryMajor = JInteger(Versions.jsBinaryMajorVersion);
                query.jsBinaryMinor = JInteger(Versions.jsBinaryMinorVersion);
                ModuleSearchResult? results
                        = ctx.typeChecker.context.repositoryManager
                            .completeModules(query);
                if (!exists results) { //TODO: can completeModules() truly return null?
                    return;
                }

                value supportsLinkedModeInArguments = ctx.options.linkedModeArguments;

                for (mod in results.results) {
                    value name = mod.name;
                    if (name!=Module.defaultModuleName,
                        !moduleAlreadyImported(ctx, name)) {

                        if (supportsLinkedModeInArguments) {
                            platformServices.completion.newModuleProposal {
                                offset = offset;
                                prefix = prefix;
                                len = len;
                                versioned = getModuleString {
                                    withBody = withBody;
                                    name = name;
                                    version = mod.lastVersion.version;
                                    namespace = !namespace exists then mod.lastVersion.namespace;
                                };
                                mod = mod;
                                withBody = withBody;
                                version = mod.lastVersion;
                                name = name;
                                node = node;
                                cpc = ctx;
                            };
                        } else {
                            for (version in mod.versions) {
                                platformServices.completion.newModuleProposal {
                                    offset = offset;
                                    prefix = prefix;
                                    len = len;
                                    versioned = getModuleString {
                                        withBody = withBody;
                                        name = name;
                                        version = version.version;
                                        namespace = !namespace exists then mod.lastVersion.namespace;
                                    };
                                    mod = mod;
                                    withBody = withBody;
                                    version = version;
                                    name = name;
                                    node = node;
                                    cpc = ctx;
                                };
                            }
                        }
                    }
                }
            }
        }
    }

    Boolean moduleAlreadyImported(LocalAnalysisResult cpc, String mod) {
        if (mod == Module.languageModuleName) {
            return true;
        }

        if (exists md = cpc.parsedRootNode.moduleDescriptors[0],
            exists iml = md.importModuleList) {
            for (im in iml.importModules) {
                if (exists path = nodes.getImportedModuleName(im),
                    path == mod) {
                    return true;
                }
            }
        }
        //Disabled, because once the module is imported, it hangs around!
        //        for (ModuleImport mi: node.getUnit().getPackage().getModule().getImports()) {
        //            if (mi.getModule().getNameAsString().equals(mod)) {
        //                return true;
        //            }
        //        }
        return false;
    }
    
    String getModuleString(Boolean withBody, variable String name, String version, String? namespace = null) {
        if (!nativeString(name).matches("^[a-z_]\\w*(\\.[a-z_]\\w*)*$")) {
            name = "\"``name``\"";
        }
        
        value ns
                = if (exists namespace, !isImplicitNamespace(namespace))
                then namespace + ":"
                else "";
        
        return withBody then "``ns````name`` \"``version``\";" else name;
    }

    shared void addModuleDescriptorCompletion(CompletionContext ctx, Integer offset, String prefix) {
        if ("module".startsWith(prefix),
            exists moduleName = getPackageName(ctx.lastCompilationUnit)) {
            value text = "module ``moduleName`` \"1.0.0\" {}";
            platformServices.completion.newModuleDescriptorProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                desc = "module " + moduleName;
                text = text;
                selectionStart
                        = offset - prefix.size
                        + (text.firstOccurrence('"') else 0) + 1;
                selectionEnd = "1.0.0".size;
            };
        }
    }

}

shared abstract class ModuleProposal
        (Integer offset, String prefix, Integer len, String versioned, ModuleDetails mod,
         Boolean withBody, ModuleVersionDetails version, String name, Node node, CompletionContext cpc)
        extends AbstractCompletionProposal
        (offset, prefix, versioned, versioned[len...]) {

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
        value off = offset + versioned.size - prefix.size - len;
        if (withBody) {
            value verlen = version.version.size;
            return DefaultRegion(off-verlen-2, verlen);
        }
        else {
            return DefaultRegion(off, 0);
        }
    }
    
    // TODO move to CompletionServices
    shared formal void newModuleProposal(ProposalsHolder proposals,
            ModuleVersionDetails d, DefaultRegion selection, LinkedMode lm);

    shared actual void applyInternal(CommonDocument document) {
        super.applyInternal(document);
        
        if (withBody, //module.getVersions().size()>1 && //TODO: put this back in when sure it works
            cpc.options.linkedModeArguments) {
            
            value linkedMode = platformServices.createLinkedMode(document);
            value selection = getSelectionInternal(document);
            value proposals = platformServices.completion.createProposalsHolder();

            for (d in mod.versions) {
                newModuleProposal(proposals, d, selection, linkedMode);
            }
            
            value x = selection.start;
            value y = selection.length;
            linkedMode.addEditableRegion(x, y, 0, proposals);
            linkedMode.install(this, 1, x + y + 2);
        }
    }
}
