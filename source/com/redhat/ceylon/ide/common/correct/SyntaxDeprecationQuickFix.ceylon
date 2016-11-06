import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning,
    Warning
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    VisitorAdaptor
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.model.typechecker.model {
    TypeDeclaration
}

"Quick fixes for [[Warning.syntaxDeprecation]]."
object syntaxDeprecationQuickFix {

    shared void addProposal(QuickFixData data, UsageWarning warning ) {
        if (warning.warningName == Warning.syntaxDeprecation.name()) {
            addQualifyStaticMemberWithTypeProposal(data);
        }
    }

    "Qualifies a reference to a static member by type.

         myInt.parse(\"1\");

     becomes

         Integer.parse(\"1\");
     "
    shared void addQualifyStaticMemberWithTypeProposal(QuickFixData data) {
        if (is Tree.Primary node = data.node) {
            object vis extends VisitorAdaptor() {
                shared variable Tree.QualifiedMemberOrTypeExpression? result = null;

                shared actual void visitQualifiedMemberOrTypeExpression(Tree.QualifiedMemberOrTypeExpression that) {
                    if (that.primary == node) {
                        result = that;
                    }
                    super.visitQualifiedMemberOrTypeExpression(that);
                }
            }
            vis.visitCompilationUnit(data.rootNode);

            if (exists result = vis.result,
                result.declaration.static,
                !result.staticMethodReference,
                is TypeDeclaration type = result.declaration.container) {

                value typeName = type.getName(data.rootNode.unit);
                value change = platformServices.document.createTextChange {
                    name = "Qualify static member with type";
                    input = data.phasedUnit;
                };
                change.addEdit(ReplaceEdit {
                    start = data.node.startIndex.intValue();
                    length = data.node.distance.intValue();
                    text = typeName;
                });
                data.addQuickFix {
                    description = "Qualify '``result.identifier.text``' with '``typeName``'";
                    change = change;
                };
            }
        }
    }
}
