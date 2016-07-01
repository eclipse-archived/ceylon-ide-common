import com.redhat.ceylon.common {
    Backends
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit,
    CeylonBinaryUnit,
    IResourceAware,
    JavaUnit,
    ExternalSourceFile,
    AnyCeylonBinaryUnit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    toJavaString,
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
    
    "Returns a tuple [sourceId, target] where `sourceId` is the node
     referencing the `target `."
    shared [Node,Node]? findTarget(Tree.CompilationUnit cu, JList<CommonToken> tokens,
        DefaultRegion region) {

        value supportedBackends = Backends.any;

        value node = nodes.findNode(cu, tokens, region.start, region.end);

        switch (node)
        case (is Null) {
            return null;
        }
        case (is Tree.Declaration) {
            if (node.declarationModel.nativeBackends == supportedBackends) {
                //we're already at the declaration itself
                return null;
            }
        }
        case (is Tree.ImportPath) {
            value packageDescriptors = cu.packageDescriptors;
            value moduleDescriptors = cu.moduleDescriptors;

            if (!packageDescriptors.empty
                    && packageDescriptors.get(0).importPath == node
                || !moduleDescriptors.empty
                    && moduleDescriptors.get(0).importPath == node) {
                //we're already at the descriptor for
                //the module or package
                return null;
            }
        }
        else {}

        assert(exists node);

        value id = nodes.getIdentifyingNode(node);
        if (!exists id) {
            return null;
        }

        variable Referenceable? referenceable = nodes.getReferencedModel(node);
        switch (_referenceable = referenceable)
        case (is Null) {
            return null;
        }
        case (is Declaration) {
            variable value dec = _referenceable;

            //look for the "original" declaration,
            //ignoring narrowing synthetic declarations
            if (is TypedDeclaration _referenceable) {
                variable TypedDeclaration? od = _referenceable;
                while (exists _od = od) {
                    referenceable = dec = _od;
                    od = _od.originalDeclaration;
                }
            }
            if (dec.native) {
                //for native declarations, each subclass of
                //this hyperlink detector resolves to a
                //different native header or impl
                referenceable = resolveNative(dec, supportedBackends);
            } else {
                //for other declarations, the subclasses of
                //this hyperlink detector are disabled
                if (!supportedBackends.none()) {
                    return null;
                }
            }
        }
        else {
            //for module or package descriptors, the
            //subclasses of this hyperlink detector are
            //disabled
            if (!supportedBackends.none()) {
                return null;
            }
        }

        if (exists r = nodes.getReferencedNode(referenceable)) {
            return [id, r];
        }
        return null;
    }

    shared Referenceable? resolveNative(Declaration dec, Backends backends) {
        if (backends.none()) {
            return null;
        }
        
        if (is AnyCeylonBinaryUnit binaryUnit = dec.unit) {
            //declarations obtained directly from Java 
            //binaries don't include all the native impls,
            //so look for it in the corresponding source
            if (exists phasedUnit = binaryUnit.phasedUnit) {
                value sourceFile = phasedUnit.unit;
                value sourceRelativePath = binaryUnit.ceylonModule
                        .toSourceUnitRelativePath(binaryUnit.relativePath);
                value isCeylon = sourceRelativePath?.endsWith(".ceylon") else false;
                for (sourceDecl in sourceFile.declarations) {
                    Boolean thisOne = isCeylon 
                        then sourceDecl == dec
                        else sourceDecl.qualifiedNameString
                                == dec.qualifiedNameString;
                    if (thisOne) {
                        return ModelUtil.getNativeDeclaration(sourceDecl, backends);
                    }
                }
            }
        }
        
        return ModelUtil.getNativeDeclaration(dec, backends);
    }

    shared default Target? gotoDeclaration(Referenceable? model) {
        if (exists model) {
            if (is CeylonUnit ceylonUnit = model.unit) {
                if (exists node = nodes.getReferencedNodeInUnit {
                    model = model;
                    rootNode = ceylonUnit.compilationUnit;
                }) {
                    return gotoNode(node, null);
                }
                else if (is CeylonBinaryUnit<out Anything,out Anything,out Anything> 
                            ceylonUnit) {
                    //special case for Java source in ceylon.language!
                    if (exists path 
                            = toJavaString(ceylonUnit.sourceRelativePath), 
                        path.endsWith(".java"), 
                        is Declaration model) {
                        return gotoJavaNode(model);
                    }
                }
            }
            else if (is Declaration model,
                is JavaUnit<out Anything,out Anything,out Anything,out Anything,out Anything> 
                        unit = model.unit) {
                return gotoJavaNode(model);
            }
        }
        return null;
    }
    
    shared Target? gotoNode(Node node, Tree.CompilationUnit? rootNode) {
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
            if (is ExternalSourceFile |
                   CeylonBinaryUnit<out Anything,out Anything,out Anything>
                   unit) {
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
