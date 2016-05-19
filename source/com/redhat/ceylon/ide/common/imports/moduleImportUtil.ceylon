import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.common {
    Backends
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.correct {
    QuickFixData
}
import com.redhat.ceylon.ide.common.model {
    AnyProjectSourceFile
}
import com.redhat.ceylon.ide.common.modulesearch {
    ModuleVersionNode,
    ModuleNode
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    DeleteEdit,
    TextChange,
    CommonDocument
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

import java.lang {
    ObjectArray,
    JString=String
}
import java.util {
    Collections
}

shared object moduleImportUtil {

    PhasedUnit? findPhasedUnit(Module mod) {
        if (is AnyProjectSourceFile unit = mod.unit) {
            return unit.phasedUnit;
        }
        return null;
    }

    shared void exportModuleImports(QuickFixData data, Module target, String moduleName) {
        if (exists pu = findPhasedUnit(target)) {
            exportModuleImports2(pu, moduleName);
        }
    }

    shared void removeModuleImports(QuickFixData data, Module target, List<String> moduleNames) {
        if (!moduleNames.empty,
            exists pu = findPhasedUnit(target)) {
            removeModuleImports2(pu, moduleNames);
        }
    }

    shared void exportModuleImports2(PhasedUnit pu, String moduleName) {
        value change = platformServices.createTextChange("Export Module Imports", pu);
        change.initMultiEdit();

        value edit = createExportEdit(pu.compilationUnit, moduleName);
        if (exists edit) {
            change.addEdit(edit);
            change.apply();
        }
    }
    
    shared void removeModuleImports2(PhasedUnit pu, List<String> moduleNames) {
        value change = platformServices.createTextChange("Remove Module Imports", pu);
        change.initMultiEdit();

        for (moduleName in moduleNames) {
            value edit = createRemoveEdit(pu.compilationUnit, moduleName);
            if (exists edit) {
                change.addEdit(edit);
            }
        }
        
        if (change.hasEdits) {
            change.apply();
        }
    }

    shared void addModuleImport(Module target, String moduleName, String moduleVersion) {
        
        value versionNode = ModuleVersionNode(ModuleNode(moduleName, 
            Collections.emptyList<ModuleVersionNode>()), moduleVersion);
        
        value offset = addModuleImports2(target, 
            map({moduleName -> versionNode}));
        
        if (exists pu = findPhasedUnit(target)) {
            value indent = platformServices.defaultIndent;
            
            platformServices.gotoLocation { 
                unit = pu.unit; 
                offset = offset + moduleName.size + indent.size + 10;
                length = moduleVersion.size;
            };
        }        
    }

    shared void makeModuleImportShared(QuickFixData data, Module target,
        ObjectArray<JString> moduleNames) {
        
        if (exists pu = findPhasedUnit(target)) {
            value change = platformServices.createTextChange("Make Module Import Shared", pu);
            change.initMultiEdit();
            
            value compilationUnit = pu.compilationUnit;
            
            for (moduleName in moduleNames.iterable) {
                value moduleDescriptor = compilationUnit.moduleDescriptors.get(0);            
                value importModules = moduleDescriptor.importModuleList.importModules;
                
                for (im in importModules) {
                    value importedName = nodes.getImportedModuleName(im);
                    if (exists importedName, exists moduleName,
                        javaString(importedName).equals(moduleName)) {
                        
                        if (!removeSharedAnnotation(change, im.annotationList)) {
                            change.addEdit(InsertEdit(im.startIndex.intValue(), "shared "));
                        }
                    }
                }
            }
            
            if (change.hasEdits) {
                change.apply();
            }
        }
    }

    shared Boolean removeSharedAnnotation(TextChange change,
        Tree.AnnotationList al) {
        
        variable value result = false;
        for (a in al.annotations) {
            assert (is Tree.BaseMemberExpression bme = a.primary);
            if (bme.declaration.name.equals("shared")) {
                variable value stop = a.endIndex.intValue();
                value start = a.startIndex.intValue();

                while (change.document.getChar(stop).whitespace) {
                    stop++;
                }
                
                change.addEdit(DeleteEdit(start, stop - start));
                result = true;
            }
        }
        
        return result;
    }
    
    Integer addModuleImports2(Module target,
        Map<String,ModuleVersionNode> moduleNamesAndVersions) {
        
        if (!moduleNamesAndVersions.empty,
            exists pu = findPhasedUnit(target)) {
            return addModuleImports3(pu, moduleNamesAndVersions);
        }
        
        return 0;
    }

    shared Integer addModuleImports3(PhasedUnit pu,
        Map<String,ModuleVersionNode> moduleNamesAndVersions) {
        
        value change = platformServices.createTextChange("Add Module Imports", pu);
        change.initMultiEdit();
        
        for (name -> val in moduleNamesAndVersions) {
            value version = val.version;
            value mod = pu.compilationUnit.unit.\ipackage.\imodule;

            value nativeBackend = 
            if (exists moduleBackends = mod.nativeBackends,
                exists otherBackend = val.nativeBackend,
                moduleBackends == otherBackend)
            
                then null
                else val.nativeBackend;
            
            value edit = createAddEdit(pu.compilationUnit, nativeBackend, name,
                version, change.document);
            
            if (exists edit) {
                change.addEdit(edit);
            }
        }
        
        if (change.hasEdits) {
            change.apply();
        }

        return change.offset;
    }


    InsertEdit? createAddEdit(Tree.CompilationUnit unit, Backends? backend,
        String moduleName, String moduleVersion, CommonDocument doc) {
        
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        Integer offset = (iml.importModules.empty)
            then iml.startIndex.intValue() + 1
            else iml.importModules.get(iml.importModules.size() - 1).endIndex.intValue();
        
        value newline = doc.defaultLineDelimiter;
        value importModule = StringBuilder();
        appendImportStatement(importModule, false, backend, moduleName, moduleVersion, newline, doc);
        if (iml.endToken.line == iml.token.line) {
            importModule.append(newline);
        }
        
        return InsertEdit(offset, importModule.string);
    }

    void appendImportStatement(StringBuilder importModule, 
        Boolean shared, Backends? backend, String moduleName,
         String moduleVersion, String newline, CommonDocument doc) {
        
        importModule.append(newline)
                .append(platformServices.defaultIndent);
        
        if (shared) {
            importModule.append("shared ");
        }
        
        if (exists backend) {
            appendNative(importModule, backend);
            importModule.append(" ");
        }
        
        importModule.append("import ");
        if (!javaString(moduleName).matches("^[a-z_]\\w*(\\.[a-z_]\\w*)*$")) {
            importModule.append("\"")
                    .append(moduleName)
                    .append("\"");
        } else {
            importModule.append(moduleName);
        }
        
        importModule.append(" \"")
                .append(moduleVersion)
                .append("\";");
    }

    shared void appendNative(StringBuilder builder, Backends backends) {
        builder.append("native(");
        appendNativeBackends(builder, backends);
        builder.append(")");
    }
    
    shared void appendNativeBackends(StringBuilder builder, Backends backends) 
            => builder.append(", ".join { for (be in backends) "\"``be.nativeAnnotation``\"" });

    
    DeleteEdit? createRemoveEdit(Tree.CompilationUnit unit, String moduleName) {
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        variable Tree.ImportModule? prev = null;
        
        for (im in iml.importModules) {
            value ip = nodes.getImportedModuleName(im);
            if (exists ip, ip.equals(moduleName)) {
                variable value startOffset = im.startIndex.intValue();
                variable value length = im.distance.intValue();
                if (exists p = prev) {
                    value endOffset = p.endIndex.intValue();
                    length += startOffset-endOffset;
                    startOffset = endOffset;
                }
                
                return DeleteEdit(startOffset, length);
            }
            
            prev = im;
        }
        
        return null;
    }

    InsertEdit? createExportEdit(Tree.CompilationUnit unit, String moduleName) {
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        for (im in iml.importModules) {
            value ip = nodes.getImportedModuleName(im);
            if (exists ip, ip.equals(moduleName)) {
                value startOffset = im.startIndex;
                return InsertEdit(startOffset.intValue(), "shared ");
            }
        }
        
        return null;
    }

    Tree.ImportModuleList? getImportList(Tree.CompilationUnit unit) {
        value moduleDescriptors = unit.moduleDescriptors;
        if (!moduleDescriptors.empty) {
            value moduleDescriptor = moduleDescriptors.get(0);
            return moduleDescriptor.importModuleList;
        } else {
            return null;
        }
    }

}
