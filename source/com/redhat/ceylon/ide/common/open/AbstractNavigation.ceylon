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
    
    shared Path? getNodePath(Node node) 
            => getUnitPath(node.unit);

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
