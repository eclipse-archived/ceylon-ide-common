import com.redhat.ceylon.common {
    Backends
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.model {
    IResourceAware,
    ExternalSourceFile,
    AnyCeylonBinaryUnit,
    AnyJavaUnit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    Path
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    Unit,
    TypedDeclaration,
    ModelUtil
}

import java.lang {
    JInteger=Integer
}
import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class AbstractNavigation<Target,NativeFile>() {
    
    "Returns a pair [sourceId, target] where `sourceId` is the node
     referencing the `target `."
    shared [Node,Node]? findTarget(Tree.CompilationUnit rootNode, 
            JList<CommonToken> tokens, DefaultRegion region,
            Backends supportedBackends = Backends.any) {
        value node = nodes.findNode(rootNode, tokens, region.start, region.end);
        value id = nodes.getIdentifyingNode(node);
        if (exists node, exists id, 
            exists result = getTarget(rootNode, node, supportedBackends)) {
            return [id, result];
        }
        return null;
    }
        
    function original(variable Declaration dec) {
        //look for the "original" declaration,
        //ignoring narrowing synthetic declarations
        while (is TypedDeclaration d = dec,
               exists od = d.originalDeclaration) {
            dec = od;
        }
        return dec;
    }

    shared Node? getTarget(Tree.CompilationUnit rootNode,
        Node? node, Backends supportedBackends = Backends.any) {
        
        if (!exists node) {
            return null;
        }

        switch (node)
        case (is Tree.Declaration) {
            if (node.declarationModel.nativeBackends == supportedBackends) {
                //we're already at the declaration itself
                return null;
            }
        }
        case (is Tree.ImportPath) {
            if (exists pd = rootNode.packageDescriptors[0],
                pd.importPath == node) {
                //we're already at the descriptor for the package
                return null;
            }
            if (exists md = rootNode.moduleDescriptors[0],
                md.importPath == node) {
                //we're already at the descriptor for the module
                return null;
            }
        }
        else {}
        
        value referenceable = nodes.getReferencedModel(node);
        Referenceable? result;
        switch (referenceable)
        case (null) {
            return null;
        }
        case (is Declaration) {
            value dec = original(referenceable);
            if (dec.native) {
                //for native declarations, each subclass of
                //this hyperlink detector resolves to a
                //different native header or impl
                result = resolveNative(dec, supportedBackends);
            } else {
                //for other declarations, the subclasses of
                //this hyperlink detector are disabled
                if (!supportedBackends.none()) {
                    return null;
                }
                result = dec;
            }
        }
        else {
            //for module or package descriptors, the
            //subclasses of this hyperlink detector are
            //disabled
            if (!supportedBackends.none()) {
                return null;
            }
            result = referenceable;
        }

        return nodes.getReferencedNode(result);
    }

    function same(Boolean isCeylon, Declaration sourceDecl, Declaration dec)
            => isCeylon
            then sourceDecl == dec
            else sourceDecl.qualifiedNameString
                    == dec.qualifiedNameString;
    
    shared Referenceable? resolveNative(Declaration dec, Backends backends) {
        if (backends.none()) {
            return null;
        }
        
        if (is AnyCeylonBinaryUnit binaryUnit = dec.unit) {
            //declarations obtained directly from Java 
            //binaries don't include all the native impls,
            //so look for it in the corresponding source
            //TODO: this code simply doesn't handle the case
            //      of the native Java source code in the
            //      language module, since it only iterates
            //      Ceylon source declarations
            if (exists phasedUnit = binaryUnit.phasedUnit) {
                value sourceRelativePath = binaryUnit.ceylonModule
                        .toSourceUnitRelativePath(binaryUnit.relativePath);
                value isCeylon = sourceRelativePath?.endsWith(".ceylon") else false;
                for (sourceDecl in phasedUnit.declarations) {
                    if (same(isCeylon, sourceDecl, dec),
                        ModelUtil.isForBackend(backends, sourceDecl.nativeBackends)) {
                        return sourceDecl;
                    }
                }
            }
        }
        
        return ModelUtil.getNativeDeclaration(dec, backends);
    }

    shared default Target? gotoDeclaration(Referenceable? model) {
        if (!exists model) {
            return null;
        }
        
        if (exists node = nodes.getReferencedNode(model)) {
            return gotoNode(node);
        }
        else {
            //model.unit can be null in IntelliJ, no idea why!
            switch (Unit? unit = model.unit)
            case (is AnyCeylonBinaryUnit) {
                //special case for Java source in ceylon.language!
                if (exists path = unit.sourceRelativePath,
                    path.endsWith(".java"),
                    is Declaration model) {
                    return gotoJavaNode(model);
                }
            }
            case (is AnyJavaUnit) {
                if (is Declaration model) {
                    return gotoJavaNode(model);
                }
            }
            else {}
            return null;
        }
    }
    
    shared Target? gotoNode(Node node, Tree.CompilationUnit? rootNode=null) {
        if (exists identifyingNode 
                = nodes.getIdentifyingNode(node)) {
            value length = identifyingNode.distance;
            value startOffset = identifyingNode.startIndex;
            if (exists unit = node.unit,
                exists rootNodeUnit = rootNode?.unit,
                unit == rootNodeUnit) {
                // TODO
                //editor.selectAndReveal(startOffset, length);
                //return editor;
            }
            else {
                if (is IResourceAware<out Anything,out Anything,NativeFile> 
                        unit = node.unit, 
                    exists file = unit.resourceFile) {
                    return gotoFile(file, startOffset, length);
                }
                else {
                    return gotoLocation(getNodePath(node), startOffset, length);
                }
            }
        }
        return null;
    }
    
    shared Path? getNodePath(Node node) => getUnitPath(node.unit);

    shared Path? getUnitPath(Unit? unit) {
        if (exists unit) {
            if (is IResourceAware<out Anything,out Anything,NativeFile> unit) {
                return if (exists fileResource = unit.resourceFile)
                    then filePath(fileResource) 
                    else Path(unit.fullPath);
            }
            if (is ExternalSourceFile|AnyCeylonBinaryUnit unit) {
                assert (exists externalPhasedUnit = unit.phasedUnit);
                return Path(externalPhasedUnit.unitFile.path);
            }
        }
        return null;
    }

    shared formal Target? gotoFile(NativeFile file, JInteger offset, JInteger length);

    shared formal Target? gotoJavaNode(Declaration declaration);
    
    shared formal Target? gotoLocation(Path? path, JInteger offset, JInteger length);
    
    shared formal Path filePath(NativeFile file);
}
