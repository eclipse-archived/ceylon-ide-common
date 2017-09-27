package org.eclipse.ceylon.ide.common.model;

import org.eclipse.ceylon.compiler.java.loader.TypeFactory;
import org.eclipse.ceylon.compiler.java.util.Util;
import org.eclipse.ceylon.compiler.typechecker.context.Context;
import org.eclipse.ceylon.compiler.typechecker.tree.Tree;
import org.eclipse.ceylon.model.loader.AbstractModelLoader;
import org.eclipse.ceylon.model.loader.JvmBackendUtil;
import org.eclipse.ceylon.model.loader.Timer;
import org.eclipse.ceylon.model.loader.TypeParser;
import org.eclipse.ceylon.model.loader.mirror.ClassMirror;
import org.eclipse.ceylon.model.typechecker.model.Declaration;
import org.eclipse.ceylon.model.typechecker.model.Modules;
import org.eclipse.ceylon.model.typechecker.model.Package;
import org.eclipse.ceylon.model.typechecker.model.Unit;
import org.eclipse.ceylon.model.typechecker.util.ModuleManager;


public abstract class AbstractModelLoaderEx extends AbstractModelLoader {
    public AbstractModelLoaderEx(ModuleManager moduleManager, Context context, Modules modules) {
        initModuleManager(moduleManager);
        ((LazyModuleManagerEx)moduleManager).initModelLoader(this);
        this.modules = modules;
        this.typeFactory = newTypeFactory(context);
        this.typeParser= newTypeParser();
        this.timer = newTimer();
        initAnnotationLoader();

    }
    
    protected abstract void initAnnotationLoader();
    protected abstract TypeParser newTypeParser();
    protected abstract Unit newTypeFactory(Context context);
    protected abstract Timer newTimer();

    public Modules getModules() {
        return modules;
    }
    
    public TypeFactory getTypeFactory() {
        return (TypeFactory) typeFactory;
    }
    
    public class PackageTypeFactoryBase extends TypeFactory {
        public PackageTypeFactoryBase(Package pkg, Context context) {
            super(context);
            assert (pkg != null);
            setPackage(pkg);
        }
    }
    
    protected String getToplevelQualifiedName(final String pkgName, String name) {
        if (name != null && ! JvmBackendUtil.isInitialLowerCase(name)) {
            name = Util.quoteIfJavaKeyword(name);
        }

        String className = pkgName.isEmpty() ? name : Util.quoteJavaKeywords(pkgName) + "." + name;
        return className;
    }
    
    protected String getToplevelQualifiedName(String fullyQualifiedName) {
        String pkgName = "";
        String name = fullyQualifiedName;
        int lastDot = fullyQualifiedName.lastIndexOf('.');
        if (lastDot > 0 && lastDot < fullyQualifiedName.length()-1) {
            pkgName = fullyQualifiedName.substring(0, lastDot);
            name = fullyQualifiedName.substring(lastDot+1, fullyQualifiedName.length());
        }
        return getToplevelQualifiedName(pkgName, name);
    }

    protected abstract boolean forceLoadFromBinaries(boolean isNativeDeclaration);
    protected abstract boolean forceLoadFromBinaries(Tree.Declaration declarationNode);
    protected abstract boolean forceLoadFromBinaries(Declaration declaration);
    protected abstract boolean forceLoadFromBinaries(ClassMirror classMirror);    
}
