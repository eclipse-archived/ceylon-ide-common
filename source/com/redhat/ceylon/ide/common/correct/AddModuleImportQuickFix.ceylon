import com.redhat.ceylon.cmr.api {
    ModuleVersionDetails
}
import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.imports {
    moduleImportUtil
}
import com.redhat.ceylon.ide.common.util {
    moduleQueries
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}

import java.lang {
    JString=String,
    JInteger=Integer,
    Long
}
import java.util {
    TreeSet,
    Collections
}

shared object addModuleImportQuickFix {
    
    function packageName(Tree.ImportPath|Tree.Import node) {
        value ip = switch (node)
                case (is Tree.ImportPath) node
                case (is Tree.Import) node.importPath;
        return TreeUtil.formatPath(ip.identifiers);
    }
    
    shared void addModuleImportProposals(QuickFixData data, TypeChecker typeChecker) {
        if (is Tree.ImportPath|Tree.Import node = data.node, 
            !data.node.unit.\ipackage.\imodule.defaultModule) {
            value name = packageName(node);
            if (data.useLazyFixes) {
                value description = "Import module containing '``name``'...";
                data.addQuickFix {
                    description = description;
                    change() => findCandidateModules {
                        data = data;
                        typeChecker = typeChecker;
                        packageName = name;
                        allVersions = true;
                    };
                    kind = QuickFixKind.addModuleImport;
                    asynchronous = true;
                    hint = description;
                    qualifiedNameIsPath = true;
                };
            } else {
                findCandidateModules {
                    data = data;
                    typeChecker = typeChecker;
                    packageName = name;
                    allVersions = false;
                };
            }
        }
    }

    void findCandidateModules(QuickFixData data, TypeChecker typeChecker,
            String packageName, Boolean allVersions) {
        value unit = data.node.unit;
        
        //We have no reason to do these lazily, except for
        //consistency of user experience
        if (JDKUtils.isJDKAnyPackage(packageName)) {
            value moduleNames = TreeSet<JString>(JDKUtils.jdkModuleNames);
            for (mod in moduleNames) {
                if (JDKUtils.isJDKPackage(mod.string, packageName)) {
                    
                    value version = JDKUtils.jdk.version;
                    data.addQuickFix {
                        description = "Add 'import ``mod`` \"``version``\"' to module descriptor";
                        image = Icons.imports;
                        qualifiedNameIsPath = true;
                        kind = QuickFixKind.addModuleImport;
                        change()
                            => moduleImportUtil.addModuleImport {
                                target = unit.\ipackage.\imodule;
                                moduleName = mod.string;
                                moduleVersion = version;
                            };
                        declaration = ModuleVersionDetails(mod.string, version);
                        affectsOtherUnits = true;
                    };
                    
                    return;
                }
            }
        }
        
        value containingModule = unit.\ipackage.\imodule;
        value query = moduleQueries.getModuleQuery {
            prefix = "";
            mod = containingModule;
            project = data.ceylonProject;
        };
        query.memberName = packageName;
        query.memberSearchPackageOnly = true;
        query.memberSearchExact = true;
        query.count = Long(10);
        query.jvmBinaryMajor = JInteger(Versions.jvmBinaryMajorVersion);
        query.jvmBinaryMinor = JInteger(Versions.jvmBinaryMinorVersion);
        query.jsBinaryMajor = JInteger(Versions.jsBinaryMajorVersion);
        query.jsBinaryMinor = JInteger(Versions.jsBinaryMinorVersion);
        value msr = typeChecker.context.repositoryManager.searchModules(query);
        
        for (md in msr.results) {
            value moduleName = md.name;
            value versions = allVersions
                then md.versions
                else Collections.singleton(md.lastVersion);
            for (version in versions) {
                value moduleVersion = version.version;
                data.addQuickFix {
                    description = "Add 'import ``moduleName`` \"``moduleVersion``\"' to module descriptor";
                    image = Icons.imports;
                    qualifiedNameIsPath = true;
                    kind = QuickFixKind.addModuleImport;
                    change()
                        => moduleImportUtil.addModuleImport {
                            target = containingModule;
                            moduleName = moduleName;
                            moduleVersion = moduleVersion;
                        };
                     declaration = version;
                    affectsOtherUnits = true;
                };
            }
        }
    }
}
