import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit,
    CeylonBinaryUnit,
    IResourceAware,
    JavaUnit,
    ExternalSourceFile
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    toJavaString,
    Path
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    Unit
}

import java.lang {
    JInteger=Integer
}

shared abstract class AbstractNavigation<Target,NativeFile>() {
    
    shared Target? gotoDeclaration(Referenceable? model) {
        if (!exists model) {
            return null;
        } else {
            if (is CeylonUnit ceylonUnit = model.unit) {
                value node = nodes.getReferencedNodeInUnit(model,
                    ceylonUnit.compilationUnit);
                
                if (exists node) {
                    return gotoNode(node, null);
                } else if (is CeylonBinaryUnit<out Anything,out Anything,out Anything> ceylonUnit) {
                    //special case for Java source in ceylon.language!
                    value binaryUnit = ceylonUnit;
                    value path = toJavaString(binaryUnit.sourceRelativePath);
                    if (exists path, path.endsWith(".java"), is Declaration model) {
                        return gotoJavaNode(model);
                    } else {
                        return null;
                    }
                } else {
                    return null;
                }
            } else if (is Declaration model,
                is JavaUnit<out Anything,out Anything,out Anything,out Anything,out Anything> unit = model.unit) {
                
                return gotoJavaNode(model);
            } else {
                return null;
            }
        }
    }
    
    shared Target? gotoNode(Node node, Tree.CompilationUnit? rootNode) {
        Unit? unit = node.unit;
        value identifyingNode = nodes.getIdentifyingNode(node);
        
        if (!exists identifyingNode) {
            return null;
        }
        value length = identifyingNode.distance;
        value startOffset = identifyingNode.startIndex;
        if (exists rootNode,
            exists unit,
            exists rootNodeUnit = rootNode.unit,
            unit == rootNodeUnit) {
            // TODO
            //editor.selectAndReveal(startOffset, length);
            //return editor;
            return null;
        } else {
            if (is IResourceAware<out Anything,out Anything,NativeFile> unit) {
                if (exists file = unit.resourceFile) {
                    return gotoFile(file, startOffset, length);
                }
            }
            
            return gotoLocation(getNodePath(node), startOffset, length);
        }
    }
    
    shared Path? getNodePath(Node node) {
        return getUnitPath(node.unit);
    }

    shared Path? getUnitPath(Unit? unit) {
        if (!exists unit) {
            return null;
        }
        
        if (is IResourceAware<out Anything,out Anything,NativeFile> unit) {
            value fileResource = unit.resourceFile;
            return if (exists fileResource)
                then filePath(fileResource) else Path(unit.fullPath);
        }
        
        if (unit is ExternalSourceFile 
            || unit is CeylonBinaryUnit<out Anything,out Anything,out Anything>) {
            
            assert (is CeylonUnit ceylonUnit = unit);
            value externalPhasedUnit = ceylonUnit.phasedUnit;
            assert(exists externalPhasedUnit);
            value file = externalPhasedUnit.unitFile;
            return Path(file.path);
        }
        
        return null;
    }

    shared formal Target? gotoFile(NativeFile file, JInteger offset, JInteger length);

    shared formal Target? gotoJavaNode(Declaration declaration);
    
    shared formal Target? gotoLocation(Path? path, JInteger offset, JInteger length);
    
    shared formal Path filePath(NativeFile file);
}
