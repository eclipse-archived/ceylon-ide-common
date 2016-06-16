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
    TreeSet
}

shared object addModuleImportQuickFix {
    
    function packageName(Tree.ImportPath|Tree.Import node) {
        Tree.ImportPath ip;
        switch (node)
        case (is Tree.ImportPath) {
            ip = node;
        }
        case (is Tree.Import) {
            ip = node.importPath;
        }
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
                    void change() {
                        findCandidateModules(data, typeChecker, name);
                    }
                    kind = QuickFixKind.addModuleImport;
                    asynchronous = true;
                    hint = description;
                };
            } else {
                findCandidateModules(data, typeChecker, name);
            }
        }
    }

    void findCandidateModules(QuickFixData data, TypeChecker typeChecker,
            String packagaName) {
        value unit = data.node.unit;
        
        //We have no reason to do these lazily, except for
        //consistency of user experience
        if (JDKUtils.isJDKAnyPackage(packagaName)) {
            value moduleNames = TreeSet<JString>(JDKUtils.jdkModuleNames);
            for (mod in moduleNames) {
                if (JDKUtils.isJDKPackage(mod.string, packagaName)) {
                    
                    data.addQuickFix {
                        description = "Add 'import ``mod`` \"``JDKUtils.jdk.version``\"' to module descriptor";
                        image = Icons.imports;
                        qualifiedNameIsPath = true;
                        kind = QuickFixKind.addModuleImport;
                        void change() {
                            moduleImportUtil.addModuleImport {
                                target = unit.\ipackage.\imodule;
                                moduleName = mod.string;
                                moduleVersion = JDKUtils.jdk.version;
                            };
                        }
                    };
                    
                    return;
                }
            }
        }
        
        value mod = unit.\ipackage.\imodule;
        value query = moduleQueries.getModuleQuery("", mod, data.ceylonProject);
        query.memberName = packagaName;
        query.memberSearchPackageOnly = true;
        query.memberSearchExact = true;
        query.count = Long(10);
        query.jvmBinaryMajor = JInteger(Versions.jvmBinaryMajorVersion);
        query.jvmBinaryMinor = JInteger(Versions.jvmBinaryMinorVersion);
        query.jsBinaryMajor = JInteger(Versions.jsBinaryMajorVersion);
        query.jsBinaryMinor = JInteger(Versions.jsBinaryMinorVersion);
        value msr = typeChecker.context.repositoryManager.searchModules(query);
        
        for (md in msr.results) {
            value name = md.name;
            value version = md.lastVersion.version;
            
            data.addQuickFix {
                description = "Add 'import ``name`` \"``version``\"' to module descriptor";
                image = Icons.imports;
                qualifiedNameIsPath = true;
                kind = QuickFixKind.addModuleImport;
                void change() 
                        => moduleImportUtil.addModuleImport {
                            target = unit.\ipackage.\imodule;
                            moduleName = name;
                            moduleVersion = version;
                        };
            };
        }
    }
}
